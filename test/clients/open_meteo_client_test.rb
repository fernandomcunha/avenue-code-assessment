require "test_helper"

class OpenMeteoClientTest < ActiveSupport::TestCase
  setup do
    @client = OpenMeteoClient.new
    @latitude = 37.3228934
    @longitude = -122.0322895
    @endpoint = "https://api.open-meteo.com/v1/forecast"
  end

  test "fetches and parses current temperature and 7-day outlook with expected query params" do
    stub = stub_request(:get, @endpoint)
      .with(query: {
        "latitude" => @latitude.to_s,
        "longitude" => @longitude.to_s,
        "current" => "temperature_2m",
        "daily" => "temperature_2m_max,temperature_2m_min",
        "temperature_unit" => "fahrenheit",
        "timezone" => "auto",
        "forecast_days" => "7"
      })
      .to_return(
        status: 200,
        body: file_fixture("open_meteo_forecast.json").read,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.forecast_at(latitude: @latitude, longitude: @longitude)

    assert_requested stub
    assert_equal 54.2, result.current_temperature
    assert_equal 7, result.daily_outlook.size
    assert_equal Forecast::Day.new(date: Date.new(2026, 11, 16), high: 58.1, low: 42.0), result.daily_outlook.first
    assert_equal Forecast::Day.new(date: Date.new(2026, 11, 22), high: 64.1, low: 46.3), result.daily_outlook.last
  end

  test "maps timeouts to ForecastUnavailable" do
    stub_request(:get, @endpoint).with(query: hash_including({})).to_timeout

    assert_raises(ForecastLookup::ForecastUnavailable) do
      @client.forecast_at(latitude: @latitude, longitude: @longitude)
    end
  end

  test "maps connection failures to ForecastUnavailable" do
    stub_request(:get, @endpoint).with(query: hash_including({})).to_raise(Faraday::ConnectionFailed.new("refused"))

    assert_raises(ForecastLookup::ForecastUnavailable) do
      @client.forecast_at(latitude: @latitude, longitude: @longitude)
    end
  end

  test "maps non-2xx responses to ForecastUnavailable" do
    stub_request(:get, @endpoint).with(query: hash_including({})).to_return(status: 503, body: "Service Unavailable")

    assert_raises(ForecastLookup::ForecastUnavailable) do
      @client.forecast_at(latitude: @latitude, longitude: @longitude)
    end
  end

  test "maps malformed JSON to ForecastUnavailable" do
    stub_request(:get, @endpoint)
      .with(query: hash_including({}))
      .to_return(status: 200, body: "not-json", headers: { "Content-Type" => "application/json" })

    assert_raises(ForecastLookup::ForecastUnavailable) do
      @client.forecast_at(latitude: @latitude, longitude: @longitude)
    end
  end

  test "maps missing or mismatched fields to ForecastUnavailable" do
    stub_request(:get, @endpoint)
      .with(query: hash_including({}))
      .to_return(
        status: 200,
        body: { "current" => {}, "daily" => { "time" => [ "2026-11-16" ] } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    assert_raises(ForecastLookup::ForecastUnavailable) do
      @client.forecast_at(latitude: @latitude, longitude: @longitude)
    end
  end
end
