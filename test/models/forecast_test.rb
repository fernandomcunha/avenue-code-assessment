require "test_helper"

class ForecastTest < ActiveSupport::TestCase
  setup do
    @days = [
      Forecast::Day.new(date: Date.new(2026, 11, 16), high: 68.4, low: 51.2),
      Forecast::Day.new(date: Date.new(2026, 11, 17), high: 70.1, low: 52.8)
    ]
    @fetched_at = Time.utc(2026, 11, 16, 12, 0, 0)
    @forecast = Forecast.new(
      zip_code: ZipCode.parse("95014"),
      current_temperature: 62.5,
      daily_outlook: @days,
      fetched_at: @fetched_at
    )
  end

  test "first_day returns the earliest day in daily_outlook regardless of order" do
    later = Forecast::Day.new(date: Date.new(2026, 11, 18), high: 72.0, low: 54.0)
    earliest = Forecast::Day.new(date: Date.new(2026, 11, 16), high: 68.4, low: 51.2)
    forecast = Forecast.new(
      zip_code: ZipCode.parse("95014"),
      current_temperature: 62.5,
      daily_outlook: [ later, earliest ],
      fetched_at: @fetched_at
    )

    assert_equal earliest, forecast.first_day
  end

  test "to_cache returns a plain hash of primitives" do
    cached = @forecast.to_cache

    assert_kind_of Hash, cached
    assert_primitives_only(cached)
    assert_equal "95014", cached["zip_code"]
    assert_equal 62.5, cached["current_temperature"]
    assert_equal "2026-11-16T12:00:00Z", cached["fetched_at"]
    assert_equal [
      { "date" => "2026-11-16", "high" => 68.4, "low" => 51.2 },
      { "date" => "2026-11-17", "high" => 70.1, "low" => 52.8 }
    ], cached["daily_outlook"]
  end

  test "from_cache round-trips back to an equal Forecast" do
    restored = Forecast.from_cache(@forecast.to_cache)

    assert_equal @forecast, restored
  end

  private

  def assert_primitives_only(value)
    case value
    when Hash
      value.each do |k, v|
        assert_kind_of String, k
        assert_primitives_only(v)
      end
    when Array
      value.each { |item| assert_primitives_only(item) }
    when String, Numeric
      assert true
    else
      flunk "Unexpected non-primitive value in cache payload: #{value.class}"
    end
  end
end
