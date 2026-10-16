# HTTP client for chatwoot-backend (github.com/pantry-snacks/chatwoot-backend),
# which reads the PantryClub database. One method per backend endpoint.
module Custom::PantryclubApi
  TIMEOUT_SECONDS = 5

  module_function

  # Returns { user_id:, latest_order_id:, latest_order_status: } or nil when no
  # PantryClub user has this phone. Order fields are nil when the user never ordered.
  def customer_by_phone(phone)
    response = get('/v1/customers/by-phone', phone: phone)
    return if response.not_found?

    {
      user_id: response['userId'],
      latest_order_id: response['latestOrderId'],
      latest_order_status: response['latestOrderStatus']
    }
  end

  def get(path, query)
    response = HTTParty.get(
      "#{ENV.fetch('PANTRYCLUB_API_URL')}#{path}",
      query: query,
      headers: { 'Authorization' => "Bearer #{ENV.fetch('PANTRYCLUB_API_TOKEN')}" },
      timeout: TIMEOUT_SECONDS
    )
    raise "PantryClub API #{path} failed with #{response.code}: #{response.body}" unless response.success? || response.not_found?

    response
  end
  private_class_method :get
end
