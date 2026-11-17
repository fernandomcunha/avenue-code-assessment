# Formatting and cache-status helpers for forecast views.
module ForecastsHelper
  def format_temperature(temp)
    "#{format('%.1f', temp)}°F"
  end

  def cache_age_minutes(result)
    result.age_minutes
  end

  def cache_refresh_minutes(result)
    result.refresh_minutes
  end
end
