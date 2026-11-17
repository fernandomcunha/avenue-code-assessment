# Orchestrates address-to-ZIP resolution, 30-minute ZIP-keyed caching, and forecast fetching.
class ForecastLookup
  CACHE_TTL = 30.minutes
  CACHE_KEY_PREFIX = "forecast:v1:"

  # Value object returned by ForecastLookup#call.
  class Result < Data.define(:forecast, :cached)
    def cached?
      cached
    end

    def expires_at
      forecast.fetched_at + CACHE_TTL
    end

    def age_minutes(now: Time.current)
      [ ((now - forecast.fetched_at) / 1.minute).floor, 0 ].max
    end

    def refresh_minutes(now: Time.current)
      [ ((expires_at - now) / 1.minute).ceil, 0 ].max
    end
  end

  def initialize(
    geocoder: NominatimClient.new,
    weather: OpenMeteoClient.new,
    cache: Rails.cache,
    clock: Time
  )
    @geocoder = geocoder
    @weather = weather
    @cache = cache
    @clock = clock
  end

  def call(address)
    zip_code = resolve_zip_code(address)
    cached_payload = @cache.read(cache_key(zip_code))

    if cached_payload
      return Result.new(forecast: Forecast.from_cache(cached_payload), cached: true)
    end

    forecast = fetch_forecast(zip_code)
    @cache.write(cache_key(zip_code), forecast.to_cache, expires_in: CACHE_TTL)
    Result.new(forecast: forecast, cached: false)
  end

  private

  def resolve_zip_code(address)
    zip_code = ZipCode.parse(address)

    return zip_code if zip_code

    raise AddressNotFound, "Invalid ZIP code format" if address.to_s.strip.match?(/\A[\d-]+\z/)

    @geocoder.zip_code_for(address)
  end

  def fetch_forecast(zip_code)
    latitude, longitude = @geocoder.center_point_for(zip_code)
    forecast_data = @weather.forecast_at(latitude:, longitude:)

    Forecast.new(
      zip_code: zip_code,
      current_temperature: forecast_data.current_temperature,
      daily_outlook: forecast_data.daily_outlook,
      fetched_at: @clock.now
    )
  end

  def cache_key(zip_code)
    "#{CACHE_KEY_PREFIX}#{zip_code}"
  end
end
