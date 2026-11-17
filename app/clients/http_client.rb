# Shared Faraday connection builder with JSON parsing, HTTP error raising, and timeouts.
module HttpClient
  OPEN_TIMEOUT_SECONDS = 3
  READ_TIMEOUT_SECONDS = 5

  def self.connection(url:, headers: {})
    Faraday.new(url: url, headers: headers) do |faraday|
      faraday.response :json
      faraday.response :raise_error
      faraday.options.open_timeout = OPEN_TIMEOUT_SECONDS
      faraday.options.timeout = READ_TIMEOUT_SECONDS
    end
  end
end
