require "test_helper"

class NominatimClientTest < ActiveSupport::TestCase
  setup do
    @client = NominatimClient.new
    @endpoint = "https://nominatim.openstreetmap.org/search"
  end

  test "zip_code_for returns a ZipCode and sends User-Agent and expected params" do
    stub = stub_request(:get, @endpoint)
      .with(
        query: {
          "q" => "1 Apple Park Way, Cupertino, CA",
          "countrycodes" => "us",
          "format" => "jsonv2",
          "addressdetails" => "1",
          "limit" => "1"
        },
        headers: { "User-Agent" => NominatimClient::USER_AGENT }
      )
      .to_return(
        status: 200,
        body: file_fixture("nominatim_address_found.json").read,
        headers: { "Content-Type" => "application/json" }
      )

    zip_code = @client.zip_code_for("1 Apple Park Way, Cupertino, CA")

    assert_requested stub
    assert_equal ZipCode.parse("95014"), zip_code
  end

  test "zip_code_for normalizes ZIP+4 postcodes to 5 digits" do
    stub_request(:get, @endpoint)
      .with(query: hash_including("q" => "1 Apple Park Way"))
      .to_return(
        status: 200,
        body: file_fixture("nominatim_address_zip4.json").read,
        headers: { "Content-Type" => "application/json" }
      )

    assert_equal ZipCode.parse("95014"), @client.zip_code_for("1 Apple Park Way")
  end

  test "zip_code_for raises AddressNotFound on empty result" do
    stub_request(:get, @endpoint)
      .with(query: hash_including("q" => "Nowhere Special"))
      .to_return(
        status: 200,
        body: file_fixture("nominatim_empty.json").read,
        headers: { "Content-Type" => "application/json" }
      )

    assert_raises(ForecastLookup::AddressNotFound) do
      @client.zip_code_for("Nowhere Special")
    end
  end

  test "zip_code_for raises ZipCodeMissing when postcode is absent" do
    stub_request(:get, @endpoint)
      .with(query: hash_including("q" => "Cupertino, CA"))
      .to_return(
        status: 200,
        body: file_fixture("nominatim_address_without_postcode.json").read,
        headers: { "Content-Type" => "application/json" }
      )

    assert_raises(ForecastLookup::ZipCodeMissing) do
      @client.zip_code_for("Cupertino, CA")
    end
  end

  test "center_point_for returns [lat, lon] floats with structured query and User-Agent" do
    stub = stub_request(:get, @endpoint)
      .with(
        query: {
          "postalcode" => "95014",
          "country" => "us",
          "format" => "jsonv2",
          "addressdetails" => "1",
          "limit" => "1"
        },
        headers: { "User-Agent" => NominatimClient::USER_AGENT }
      )
      .to_return(
        status: 200,
        body: file_fixture("nominatim_center_point.json").read,
        headers: { "Content-Type" => "application/json" }
      )

    coords = @client.center_point_for(ZipCode.parse("95014"))

    assert_requested stub
    assert_equal [ 37.3228934, -122.0322895 ], coords
  end

  test "center_point_for raises ForecastUnavailable on empty result" do
    stub_request(:get, @endpoint)
      .with(query: hash_including("postalcode" => "99999"))
      .to_return(
        status: 200,
        body: file_fixture("nominatim_empty.json").read,
        headers: { "Content-Type" => "application/json" }
      )

    assert_raises(ForecastLookup::ForecastUnavailable) do
      @client.center_point_for(ZipCode.parse("99999"))
    end
  end

  test "maps timeouts to ForecastUnavailable" do
    stub_request(:get, @endpoint).with(query: hash_including({})).to_timeout

    assert_raises(ForecastLookup::ForecastUnavailable) do
      @client.zip_code_for("Cupertino, CA")
    end
  end

  test "maps connection failures to ForecastUnavailable" do
    stub_request(:get, @endpoint).with(query: hash_including({})).to_raise(Faraday::ConnectionFailed.new("refused"))

    assert_raises(ForecastLookup::ForecastUnavailable) do
      @client.center_point_for("95014")
    end
  end

  test "maps non-2xx responses to ForecastUnavailable" do
    stub_request(:get, @endpoint).with(query: hash_including({})).to_return(status: 503, body: "Service Unavailable")

    assert_raises(ForecastLookup::ForecastUnavailable) do
      @client.zip_code_for("Cupertino, CA")
    end
  end

  test "maps malformed JSON to ForecastUnavailable" do
    stub_request(:get, @endpoint)
      .with(query: hash_including({}))
      .to_return(status: 200, body: "not-json", headers: { "Content-Type" => "application/json" })

    assert_raises(ForecastLookup::ForecastUnavailable) do
      @client.center_point_for("95014")
    end
  end
end
