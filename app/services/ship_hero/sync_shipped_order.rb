# frozen_string_literal: true

module ShipHero
  class SyncShippedOrder
    attr_reader :payload, :company_id, :fluid_api_token

    def initialize(payload, company_id)
      @payload = payload
      @company_id = company_id
      initialize_credentials
    end

    def call
      begin
        # Extract ShipHero order details from webhook payload
        shipment_data = extract_shipment_data
        return nil if shipment_data.nil?

        # Get Fluid order ID from ShipHero external reference
        fluid_order_id = shipment_data[:fluid_order_id]
        return nil if fluid_order_id.nil?

        # Retrieve the full order from Fluid
        fluid_order = retrieve_fluid_order(fluid_order_id)
        return nil if fluid_order.nil?

        # Create fulfillment in Fluid with tracking information
        fulfillment = create_fulfillment(
          fluid_order: fluid_order,
          tracking_number: shipment_data[:tracking_number]
        )

        Rails.logger.info("Order fulfillment created for Fluid order #{fluid_order_id}")
        fulfillment
      rescue StandardError => e
        Rails.logger.error("Error syncing shipped order: #{e.message} - SyncShippedOrder")
        nil
      end
    end

  private

    def initialize_credentials
      company = Company.find(@company_id)
      raise "Company not found for ID: #{@company_id}" unless company

      integration_setting = IntegrationSetting.find_by(company_id: company.id)
      raise "Integration settings not found for company: #{company.id}" unless integration_setting

      @fluid_api_token = integration_setting.settings["fluid_api_token"]

      raise "Missing Fluid API token for company: #{@company_id}" if @fluid_api_token.blank?
    end

    def extract_shipment_data
      # ShipHero webhook payload structure for shipment_update
      # This will depend on ShipHero's actual webhook structure
      # You may need to adjust based on their API documentation

      # Example payload structure (adjust as needed):
      # {
      #   "order_id": "123456",
      #   "order_number": "FLUID-12345",
      #   "tracking_number": "1Z999AA10123456784",
      #   "carrier": "UPS",
      #   "shipped_date": "2025-01-15T10:30:00Z"
      # }

      order_number = payload.dig("order_number")
      tracking_number = payload.dig("tracking_number")

      unless order_number && tracking_number
        Rails.logger.warn("Missing required fields in ShipHero webhook payload")
        return nil
      end

      # The order_number should match the Fluid order ID or order_number
      # Depending on how you set up the initial order creation
      {
        fluid_order_id: extract_fluid_order_id(order_number),
        tracking_number: tracking_number,
        carrier: payload.dig("carrier"),
        shipped_date: payload.dig("shipped_date"),
      }
    end

    def extract_fluid_order_id(order_number)
      # If you stored the Fluid order ID in the order_number field,
      # extract it here. Otherwise, you may need to query your database
      # to find the mapping between ShipHero order and Fluid order.

      # For now, assuming order_number contains or is the Fluid order ID
      order_number
    end

    def retrieve_fluid_order(fluid_order_id)
      fluid_order = fluid_commerce_order_service.retrieve_order(id: fluid_order_id)
      parsed_fluid_order = JSON.parse(fluid_order.body, symbolize_names: true)

      # Check if the response indicates order not found
      if parsed_fluid_order.blank? || parsed_fluid_order["error"]
        Rails.logger.info("No Fluid order found for ID #{fluid_order_id}")
        return nil
      end

      parsed_fluid_order
    rescue StandardError => e
      Rails.logger.error("Failed to retrieve Fluid order #{fluid_order_id}: #{e.message}")
      nil
    end

    def create_fulfillment(fluid_order:, tracking_number:)
      fluid_order_id = fluid_order.dig(:order, :id)
      order_items = fluid_order.dig(:order, :items)

      unless fluid_order_id && order_items
        Rails.logger.error("Invalid Fluid order structure")
        return nil
      end

      fulfillment_response = fluid_commerce_order_service.order_fulfillment(
        id: fluid_order_id,
        order_items: order_items,
        tracking_number: tracking_number
      )

      parsed_fulfillment_response = JSON.parse(fulfillment_response.body, symbolize_names: true)

      if parsed_fulfillment_response.blank? || parsed_fulfillment_response["error"]
        Rails.logger.error("Failed to fulfill order #{fluid_order_id} in Fluid")
        return nil
      end

      parsed_fulfillment_response
    rescue StandardError => e
      Rails.logger.error("Failed to create fulfillment for order #{fluid_order_id}: #{e.message}")
      nil
    end

    def fluid_commerce_order_service
      @fluid_commerce_order_service ||= FluidApi::Commerce::OrderService.new(@fluid_api_token)
    end
  end
end
