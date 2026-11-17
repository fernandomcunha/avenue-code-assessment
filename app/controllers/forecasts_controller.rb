# Handles forecast lookup form rendering and ZIP-keyed forecast display.
class ForecastsController < ApplicationController
  ERROR_MESSAGES = {
    ForecastLookup::AddressNotFound => "We couldn't find that address. Try adding the city and state.",
    ForecastLookup::ZipCodeMissing => "That location doesn't map to a single ZIP code. Please enter a more specific address.",
    ForecastLookup::ForecastUnavailable => "The forecast service is unavailable right now. Please try again shortly."
  }.freeze

  def show
    return unless search_params.key?(:address)

    @address = search_params[:address]
    if @address.blank?
      @error_message = "Please enter an address or ZIP code."
      return
    end

    @result = ForecastLookup.new.call(@address)
  rescue ForecastLookup::Error => e
    @error_message = ERROR_MESSAGES.fetch(e.class)
  end

  private

  def search_params
    params.permit(:address)
  end
end
