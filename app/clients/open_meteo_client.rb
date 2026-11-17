# HTTP client for the Open-Meteo forecast API.
class OpenMeteoClient
  BASE_URL = "https://api.open-meteo.com"
  FORECAST_PATH = "/v1/forecast"
  FORECAST_DAYS = 7

  class Response < Data.define(:current_temperature, :daily_outlook)
  end

  def initialize(connection: default_connection)
    @connection = connection
  end

  def forecast_at(latitude:, longitude:)
    response = @connection.get(FORECAST_PATH, {
      latitude: latitude,
      longitude: longitude,
      current: "temperature_2m",
      daily: "temperature_2m_max,temperature_2m_min",
      temperature_unit: "fahrenheit",
      timezone: "auto",
      forecast_days: FORECAST_DAYS
    })

    parse_forecast(response.body)
  rescue Faraday::Error => e
    raise ForecastLookup::ForecastUnavailable, e.message
  end

  private

  def parse_forecast(body)
    raise ForecastLookup::ForecastUnavailable, "Invalid response body" unless body.is_a?(Hash)

    current_temperature = Float(body.dig("current", "temperature_2m"))
    dates = body.dig("daily", "time")
    highs = body.dig("daily", "temperature_2m_max")
    lows = body.dig("daily", "temperature_2m_min")

    unless valid_daily_arrays?(dates, highs, lows)
      raise ForecastLookup::ForecastUnavailable, "Missing daily forecast data"
    end

    daily_outlook = dates.zip(highs, lows).map do |date_str, high, low|
      Forecast::Day.new(
        date: Date.iso8601(date_str),
        high: Float(high),
        low: Float(low)
      )
    end

    Response.new(current_temperature:, daily_outlook:)
  rescue ArgumentError, TypeError => e
    raise ForecastLookup::ForecastUnavailable, e.message
  end

  def valid_daily_arrays?(dates, highs, lows)
    arrays = [ dates, highs, lows ]
    arrays.all? { |arr| arr.is_a?(Array) && arr.any? } &&
      dates.size == highs.size &&
      dates.size == lows.size
  end

  def default_connection
    HttpClient.connection(url: BASE_URL)
  end
end
