# Value object representing a ZIP-keyed weather forecast and its 7-day daily outlook.
class Forecast < Data.define(:zip_code, :current_temperature, :daily_outlook, :fetched_at)
  Day = Data.define(:date, :high, :low)

  def self.from_cache(payload)
    new(
      zip_code: ZipCode.parse(payload.fetch("zip_code")),
      current_temperature: payload.fetch("current_temperature"),
      daily_outlook: payload.fetch("daily_outlook").map do |day|
        Day.new(
          date: Date.iso8601(day.fetch("date")),
          high: day.fetch("high"),
          low: day.fetch("low")
        )
      end,
      fetched_at: Time.iso8601(payload.fetch("fetched_at"))
    )
  end

  def first_day
    daily_outlook.min_by(&:date)
  end

  def to_cache
    {
      "zip_code" => zip_code.to_s,
      "current_temperature" => current_temperature,
      "daily_outlook" => daily_outlook.map do |day|
        {
          "date" => day.date.iso8601,
          "high" => day.high,
          "low" => day.low
        }
      end,
      "fetched_at" => fetched_at.utc.iso8601
    }
  end
end
