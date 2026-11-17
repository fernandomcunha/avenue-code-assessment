require "test_helper"

class ForecastsTest < ActionDispatch::IntegrationTest
  test "GET / renders the address lookup form" do
    get root_path

    assert_response :success
    assert_select "form[action='#{forecast_path}'][method='get']" do
      assert_select "label", text: /Address or ZIP code/i
      assert_select "input[name='address']"
      assert_select "input[type='submit'], button[type='submit']"
    end
  end

  test "GET /forecast with an address shows results and Fetched just now" do
    stub_successful_lookup("1 Apple Park Way, Cupertino, CA")

    get forecast_path, params: { address: "1 Apple Park Way, Cupertino, CA" }

    assert_response :success
    assert_select "input[name='address'][value='1 Apple Park Way, Cupertino, CA']"
    assert_select ".forecast-result" do
      assert_select "*", text: /95014/
      assert_select "*", text: /54\.2°F/
      assert_select "*", text: /58\.1°F/
      assert_select "*", text: /42\.0°F/
      assert_select "*", text: /Fetched just now/
      assert_select "tbody tr", count: 7
      assert_select "tbody tr:first-child", text: /Monday/
      assert_select "tbody tr:last-child", text: /Sunday/
    end
  end

  test "repeating the request within 30 minutes shows From cache with age and refresh time" do
    with_memory_cache do
      travel_to Time.utc(2026, 11, 16, 12, 0, 0) do
        stub_successful_lookup("95014")

        get forecast_path, params: { address: "95014" }
        assert_response :success
        assert_select ".cache-indicator", text: /Fetched just now/

        travel 5.minutes

        get forecast_path, params: { address: "95014" }
        assert_response :success
        assert_select ".cache-indicator", text: /From cache/
        assert_select ".cache-indicator", text: /fetched 5 min ago, refreshes in 25 min/
      end
    end
  end

  test "blank address submission shows validation message" do
    get forecast_path, params: { address: "   " }

    assert_response :success
    assert_select ".error-message", text: "Please enter an address or ZIP code."
    assert_select "input[name='address'][value='   ']"
  end

  test "AddressNotFound shows helpful message with input preserved" do
    stub_request(:get, "https://nominatim.openstreetmap.org/search")
      .with(query: hash_including("q" => "Nowhere Special"))
      .to_return(
        status: 200,
        body: file_fixture("nominatim_empty.json").read,
        headers: { "Content-Type" => "application/json" }
      )

    get forecast_path, params: { address: "Nowhere Special" }

    assert_response :success
    assert_select ".error-message", text: "We couldn't find that address. Try adding the city and state."
    assert_select "input[name='address'][value='Nowhere Special']"
  end

  test "partial numeric ZIP input shows AddressNotFound without geocoding" do
    get forecast_path, params: { address: "9501" }

    assert_response :success
    assert_select ".error-message", text: "We couldn't find that address. Try adding the city and state."
    assert_select "input[name='address'][value='9501']"
  end

  test "ZipCodeMissing shows helpful message with input preserved" do
    stub_request(:get, "https://nominatim.openstreetmap.org/search")
      .with(query: hash_including("q" => "Cupertino, CA"))
      .to_return(
        status: 200,
        body: file_fixture("nominatim_address_without_postcode.json").read,
        headers: { "Content-Type" => "application/json" }
      )

    get forecast_path, params: { address: "Cupertino, CA" }

    assert_response :success
    assert_select ".error-message", text: "That location doesn't map to a single ZIP code. Please enter a more specific address."
    assert_select "input[name='address'][value='Cupertino, CA']"
  end

  test "ForecastUnavailable shows helpful message with input preserved" do
    stub_request(:get, "https://nominatim.openstreetmap.org/search")
      .with(query: hash_including("postalcode" => "95014"))
      .to_return(
        status: 200,
        body: file_fixture("nominatim_center_point.json").read,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:get, "https://api.open-meteo.com/v1/forecast")
      .with(query: hash_including("latitude" => "37.3228934"))
      .to_return(status: 503, body: "")

    get forecast_path, params: { address: "95014" }

    assert_response :success
    assert_select ".error-message", text: "The forecast service is unavailable right now. Please try again shortly."
    assert_select "input[name='address'][value='95014']"
  end

  private

  def stub_successful_lookup(address)
    stub_request(:get, "https://nominatim.openstreetmap.org/search")
      .with(query: hash_including("q" => address))
      .to_return(
        status: 200,
        body: file_fixture("nominatim_address_found.json").read,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:get, "https://nominatim.openstreetmap.org/search")
      .with(query: hash_including("postalcode" => "95014"))
      .to_return(
        status: 200,
        body: file_fixture("nominatim_center_point.json").read,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:get, "https://api.open-meteo.com/v1/forecast")
      .with(query: hash_including("latitude" => "37.3228934", "longitude" => "-122.0322895"))
      .to_return(
        status: 200,
        body: file_fixture("open_meteo_forecast.json").read,
        headers: { "Content-Type" => "application/json" }
      )
  end
end
