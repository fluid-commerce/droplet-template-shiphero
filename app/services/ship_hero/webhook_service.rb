# frozen_string_literal: true

module ShipHero
  class WebhookService
    attr_reader :company_id, :integration_setting

    def initialize(company_id:)
      @company_id = company_id
      @integration_setting = IntegrationSetting.find_by(company_id: company_id)
      raise "No integration setting found for company #{company_id}" unless @integration_setting
    end

    # List all webhooks configured in ShipHero
    def list_webhooks
      client = ShipHero::GraphqlClient.new(integration_setting: @integration_setting)

      query = <<~GRAPHQL
        query {
          webhooks {
            request_id
            complexity
            data(first: 50) {
              edges {
                node {
                  id
                  name
                  url
                  active
                }
              }
            }
          }
        }
      GRAPHQL

      response = client.execute_query(query)

      if response["errors"]
        Rails.logger.error "Error fetching webhooks: #{response['errors']}"
        return { success: false, errors: response["errors"] }
      end

      webhooks = response.dig("data", "webhooks", "data", "edges")&.map { |edge| edge["node"] } || []

      {
        success: true,
        webhooks: webhooks,
        request_id: response.dig("data", "webhooks", "request_id"),
        complexity: response.dig("data", "webhooks", "complexity"),
      }
    end

    # Create a new webhook in ShipHero
    # @param name [String] The webhook type (e.g., "Shipment Update", "Inventory Update")
    # @param url [String] The webhook URL to send events to
    # @param shop_name [String] Identifier for the webhook (allows multiple webhooks of same type)
    def create_webhook(name:, url:, shop_name: "fluid-droplet")
      client = ShipHero::GraphqlClient.new(integration_setting: @integration_setting)

      mutation = <<~GRAPHQL
        mutation($data: CreateWebhookInput!) {
          webhook_create(data: $data) {
            request_id
            complexity
            webhook {
              id
              legacy_id
              account_id
              shop_name
              name
              url
              source
              shared_signature_secret
            }
          }
        }
      GRAPHQL

      variables = {
        data: {
          name: name,
          url: url,
          shop_name: shop_name,
        },
      }

      response = client.execute_query(mutation, variables)

      if response["errors"]
        Rails.logger.error "Error creating webhook: #{response['errors']}"
        return { success: false, errors: response["errors"] }
      end

      webhook_data = response.dig("data", "webhook_create")
      webhook = webhook_data&.dig("webhook")

      # CRITICAL: Store the shared_signature_secret - it's only shown once!
      if webhook && webhook["shared_signature_secret"]
        store_webhook_secret(webhook["name"], webhook["shared_signature_secret"])
      end

      {
        success: true,
        webhook: webhook,
        request_id: webhook_data&.dig("request_id"),
        complexity: webhook_data&.dig("complexity"),
      }
    end

    # Delete a webhook in ShipHero
    # @param name [String] The webhook type name (e.g., "Shipment Update")
    # @param shop_name [String] The shop_name identifier used when creating the webhook
    def delete_webhook(name:, shop_name: "fluid-droplet")
      client = ShipHero::GraphqlClient.new(integration_setting: @integration_setting)

      mutation = <<~GRAPHQL
        mutation($data: DeleteWebhookInput!) {
          webhook_delete(data: $data) {
            request_id
            complexity
          }
        }
      GRAPHQL

      variables = {
        data: {
          name: name,
          shop_name: shop_name,
        },
      }

      response = client.execute_query(mutation, variables)

      if response["errors"]
        Rails.logger.error "Error deleting webhook: #{response['errors']}"
        return { success: false, errors: response["errors"] }
      end

      {
        success: true,
        request_id: response.dig("data", "webhook_delete", "request_id"),
        complexity: response.dig("data", "webhook_delete", "complexity"),
      }
    end

    # Check if the required webhooks are configured
    def check_required_webhooks(webhook_url:)
      result = list_webhooks

      unless result[:success]
        return {
          configured: false,
          message: "Failed to fetch webhooks from ShipHero",
          errors: result[:errors],
        }
      end

      webhooks = result[:webhooks]

      # Check if our webhook URL is registered
      existing_webhook = webhooks.find { |wh| wh["url"] == webhook_url && wh["active"] }

      if existing_webhook
        {
          configured: true,
          message: "Webhook is already configured",
          webhook: existing_webhook,
          all_webhooks: webhooks,
        }
      else
        {
          configured: false,
          message: "Webhook URL not found or inactive in ShipHero",
          all_webhooks: webhooks,
        }
      end
    end

    # Setup all required webhooks for this integration
    def setup_webhooks(webhook_url:)
      results = []

      # Check existing webhooks first
      check_result = check_required_webhooks(webhook_url: webhook_url)

      if check_result[:configured]
        return {
          success: true,
          message: "Webhooks already configured",
          webhook: check_result[:webhook],
        }
      end

      # Create the webhook for order shipments
      # The 'name' field specifies the webhook type in ShipHero
      # Available types: "Shipment Update", "Inventory Update", "Order Canceled", etc.
      create_result = create_webhook(
        name: "Shipment Update",  # This is the webhook type selector!
        url: webhook_url,
        shop_name: "fluid-droplet"
      )

      if create_result[:success]
        {
          success: true,
          message: "Webhook created successfully",
          webhook: create_result[:webhook],
          request_id: create_result[:request_id],
          shared_signature_secret: create_result[:webhook]["shared_signature_secret"],
        }
      else
        {
          success: false,
          message: "Failed to create webhook",
          errors: create_result[:errors],
        }
      end
    end

  private

    def store_webhook_secret(webhook_name, secret)
      # Store the webhook secret in integration settings
      # This is critical for HMAC verification and is only shown once!
      current_secrets = @integration_setting.credentials["webhook_secrets"] || {}
      current_secrets[webhook_name] = secret

      @integration_setting.credentials = @integration_setting.credentials.merge({
        "webhook_secrets" => current_secrets,
      })

      @integration_setting.save!

      Rails.logger.info "Stored webhook secret for: #{webhook_name}"
    rescue StandardError => e
      Rails.logger.error "Failed to store webhook secret: #{e.message}"
    end
  end
end

