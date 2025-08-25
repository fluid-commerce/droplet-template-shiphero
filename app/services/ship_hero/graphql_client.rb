# frozen_string_literal: true

module ShipHero
  class GraphqlClient
    BASE_URL = "https://public-api.shiphero.com/graphql"

    def self.test_connection_for_company(company_id)
      integration_setting = IntegrationSetting.find_by(company_id: company_id)
      return { connection: false, message: "Integration setting not found for company" } unless integration_setting

      new(integration_setting).test_connection
    end

    def initialize(integration_setting)
      @integration_setting = integration_setting
      @access_token = get_access_token
    end

    def test_connection
      user_query = ShipHero::Query::User.new
      query = user_query.me

      response = execute_query(query)

      if response&.dig("data", "me", "data")
        { connection: true, message: "GraphQL connection test successful!", data: response&.dig("data", "me", "data") }
      else
        { connection: false, message: "GraphQL connection test failed!", errors: response&.dig("errors") }
      end
    rescue StandardError => e
      { connection: false, message: "GraphQL connection test failed: #{e.message}" }
    end

    def create_order(order_data)
      mutation = ShipHero::Mutation::Order.new.create_order(order_data)
      response = execute_query(mutation, { data: order_data })

      if response.is_a?(Hash) && response[:error]
        Rails.logger.error "Failed to create order: #{response[:error]}"
        Rails.logger.error "Response body: #{response[:body]}"
        return { success: false, error: response[:error], details: response[:body] }
      end

      if response&.dig("errors")
        Rails.logger.error "GraphQL errors: #{response['errors']}"
        return { success: false, error: "GraphQL errors", details: response["errors"] }
      end

      if response&.dig("data", "order_create", "order")
        order = response["data"]["order_create"]["order"]
        Rails.logger.info "Order created successfully: #{order['id']}"
        return { success: true, order: order, response: response }
      else
        Rails.logger.error "Unexpected response format: #{response}"
        return { success: false, error: "Unexpected response format", details: response }
      end
    end

    def execute_query(query, variables = {})
      headers = {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{@access_token}"
      }

      body = {
        query: query,
        variables: variables
      }

      Rails.logger.info "GraphQL Request: #{BASE_URL}"
      Rails.logger.info "Headers: #{headers.except('Authorization')}"
      Rails.logger.info "Body: #{body.to_json}"

      response = HTTParty.post(
        BASE_URL,
        headers: headers,
        body: body.to_json
      )

      Rails.logger.info "Response Status: #{response.code}"
      Rails.logger.info "Response Body: #{response.body}"

      unless response.success?
        Rails.logger.error "GraphQL request failed with status #{response.code}: #{response.body}"
        return { error: "HTTP #{response.code}", body: response.body }
      end

      begin
        JSON.parse(response.body)
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse JSON response: #{e.message}"
        Rails.logger.error "Response body: #{response.body}"
        { error: "Invalid JSON response", body: response.body }
      end
    end

    private

    def get_access_token
      # Check if we have a stored access token
      stored_token = @integration_setting.credentials&.dig("access_token")

      if stored_token
        # TODO: Add token expiration check here
        return stored_token
      end

      username = @integration_setting.settings["username"]
      password = @integration_setting.settings["password"]

      # Get new token
      auth_service = AuthenticationService.new(username: username, password: password)
      auth_response = auth_service.authenticate

      if auth_response["access_token"]
        # Store the new token
        @integration_setting.update(credentials: auth_response)
        auth_response["access_token"]
      else
        raise "Failed to authenticate with ShipHero API"
      end
    end
  end
end
