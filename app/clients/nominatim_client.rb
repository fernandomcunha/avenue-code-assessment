# HTTP client for the Nominatim geocoding API.
class NominatimClient
  BASE_URL = "https://nominatim.openstreetmap.org"
  SEARCH_PATH = "/search"
  USER_AGENT = "ZipForecast/1.0"

  def initialize(connection: default_connection)
    @connection = connection
  end

  def zip_code_for(address)
    results = search(q: address.to_s, countrycodes: "us")

    raise ForecastLookup::AddressNotFound, "Address not found" if results.empty?

    postcode = results.first.dig("address", "postcode")
    ZipCode.parse(postcode) || raise(ForecastLookup::ZipCodeMissing, "ZIP code missing from address")
  end

  def center_point_for(zip_code)
    results = search(postalcode: zip_code.to_s, country: "us")
    result = results.first

    raise ForecastLookup::ForecastUnavailable, "ZIP center point not found" unless result.is_a?(Hash)

    [ Float(result["lat"]), Float(result["lon"]) ]
  rescue ArgumentError, TypeError => e
    raise ForecastLookup::ForecastUnavailable, e.message
  end

  private

  def search(params)
    response = @connection.get(SEARCH_PATH, params.merge(
      format: "jsonv2",
      addressdetails: 1,
      limit: 1
    ))

    body = response.body
    
    raise ForecastLookup::ForecastUnavailable, "Unexpected response format" unless body.is_a?(Array)

    body
  rescue Faraday::Error => e
    raise ForecastLookup::ForecastUnavailable, e.message
  end

  def default_connection
    HttpClient.connection(url: BASE_URL, headers: { "User-Agent" => USER_AGENT })
  end
end
