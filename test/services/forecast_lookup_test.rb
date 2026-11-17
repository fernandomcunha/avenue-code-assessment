require "test_helper"

class ForecastLookupTest < ActiveSupport::TestCase
  class FakeGeocoder
    attr_reader :zip_code_calls, :center_point_calls

    def initialize(zip_codes: {}, center_points: {}, error: nil)
      @zip_codes = zip_codes
      @center_points = center_points
      @error = error
      @zip_code_calls = []
      @center_point_calls = []
    end

    def zip_code_for(address)
      @zip_code_calls << address
      raise @error if @error

      @zip_codes.fetch(address)
    end

    def center_point_for(zip_code)
      @center_point_calls << zip_code.to_s
      raise @error if @error

      @center_points.fetch(zip_code.to_s)
    end
  end

  class FakeWeather
    attr_reader :calls

    def initialize(response: nil, error: nil)
      @response = response
      @error = error
      @calls = []
    end

    def forecast_at(latitude:, longitude:)
      @calls << { latitude: latitude, longitude: longitude }
      raise @error if @error

      @response
    end
  end

  setup do
    @now = Time.utc(2026, 11, 16, 12, 0, 0)
    travel_to @now

    @cache = ActiveSupport::Cache::MemoryStore.new
    @weather_response = OpenMeteoClient::Response.new(
      current_temperature: 68.5,
      daily_outlook: [
        Forecast::Day.new(date: Date.new(2026, 11, 16), high: 75.0, low: 55.0)
      ]
    )
    @geocoder = FakeGeocoder.new(
      zip_codes: {
        "350 Fifth Ave, New York, NY" => ZipCode.parse("10118"),
        "Empire State Building, NY" => ZipCode.parse("10118")
      },
      center_points: { "10118" => [ 40.7484, -73.9857 ] }
    )
    @weather = FakeWeather.new(response: @weather_response)
    @lookup = ForecastLookup.new(
      geocoder: @geocoder,
      weather: @weather,
      cache: @cache,
      clock: Time
    )
  end

  test "cache miss calls both providers and returns fresh result" do
    result = @lookup.call("350 Fifth Ave, New York, NY")

    assert_not result.cached?
    assert_equal ZipCode.parse("10118"), result.forecast.zip_code
    assert_equal 68.5, result.forecast.current_temperature
    assert_equal @weather_response.daily_outlook, result.forecast.daily_outlook
    assert_equal @now, result.forecast.fetched_at
    assert_equal @now + 30.minutes, result.expires_at
    assert_equal [ "350 Fifth Ave, New York, NY" ], @geocoder.zip_code_calls
    assert_equal [ "10118" ], @geocoder.center_point_calls
    assert_equal [ { latitude: 40.7484, longitude: -73.9857 } ], @weather.calls
  end

  test "second call within 30 minutes returns cached result without calling providers" do
    first = @lookup.call("350 Fifth Ave, New York, NY")
    travel 10.minutes
    second = @lookup.call("350 Fifth Ave, New York, NY")

    assert second.cached?
    assert_equal first.forecast.fetched_at, second.forecast.fetched_at
    assert_equal first.forecast, second.forecast
    assert_equal 1, @geocoder.center_point_calls.size
    assert_equal 1, @weather.calls.size
  end

  test "fetches again after 31 minutes" do
    first = @lookup.call("350 Fifth Ave, New York, NY")
    travel 31.minutes
    second = @lookup.call("350 Fifth Ave, New York, NY")

    assert_not second.cached?
    assert_equal @now + 31.minutes, second.forecast.fetched_at
    assert_not_equal first.forecast.fetched_at, second.forecast.fetched_at
    assert_equal 2, @geocoder.center_point_calls.size
    assert_equal 2, @weather.calls.size
  end

  test "bare ZIP input never calls zip_code_for" do
    result = @lookup.call("10118-0001")

    assert_not result.cached?
    assert_equal ZipCode.parse("10118"), result.forecast.zip_code
    assert_empty @geocoder.zip_code_calls
    assert_equal [ "10118" ], @geocoder.center_point_calls
  end

  test "numeric-only input that is not a valid ZIP raises AddressNotFound without calling geocoder" do
    %w[9501 950141 95014-12].each do |invalid_zip|
      assert_raises(ForecastLookup::AddressNotFound) do
        @lookup.call(invalid_zip)
      end
    end

    assert_empty @geocoder.zip_code_calls
  end

  test "two different addresses resolving to the same ZIP share one cache entry" do
    first = @lookup.call("350 Fifth Ave, New York, NY")
    second = @lookup.call("Empire State Building, NY")

    assert_not first.cached?
    assert second.cached?
    assert_equal first.forecast, second.forecast
    assert_equal 1, @geocoder.center_point_calls.size
    assert_equal 1, @weather.calls.size
  end

  test "provider failure is not cached and next call retries" do
    failing_weather = FakeWeather.new(error: ForecastLookup::ForecastUnavailable.new("down"))
    lookup = ForecastLookup.new(geocoder: @geocoder, weather: failing_weather, cache: @cache, clock: Time)

    assert_raises(ForecastLookup::ForecastUnavailable) do
      lookup.call("10118")
    end

    assert_nil @cache.read("forecast:v1:10118")

    result = @lookup.call("10118")
    assert_not result.cached?
    assert_equal 1, @weather.calls.size
  end

  test "Result#age_minutes and Result#refresh_minutes compute floored age and ceiled refresh clamped at zero" do
    result = @lookup.call("10118")

    assert_equal 0, result.age_minutes(now: @now)
    assert_equal 30, result.refresh_minutes(now: @now)

    assert_equal 12, result.age_minutes(now: @now + 12.minutes + 45.seconds)
    assert_equal 18, result.refresh_minutes(now: @now + 12.minutes + 45.seconds)

    assert_equal 0, result.age_minutes(now: @now - 1.minute)
    assert_equal 0, result.refresh_minutes(now: @now + 35.minutes)
  end
end
