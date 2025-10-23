module ShipHero
  class CreateOrder
    attr_reader :params, :base_url, :fluid_api_token, :company_name

    def initialize(order_params)
      @params = order_params["order"].deep_symbolize_keys
      @company_id = order_params["company_id"]
      company = Company.find_by(fluid_company_id: @company_id)
      @company_name = company&.name

      integration_setting = IntegrationSetting.find_by(company_id: company.id)
      @username = integration_setting.settings["username"]
      @password = integration_setting.settings["password"]
      @fluid_api_token = integration_setting.settings["fluid_api_token"]
    end

    def call
      order_response = create_order_in_shiphero

      ship_hero_order_id = order_response.dig("data", "order_create", "order", "id")

      return Result.new(false, nil, "Failed to create order in ShipHero") unless ship_hero_order_id.present?

      begin
        fluid_service = FluidApi::V2::OrdersService.new(fluid_api_token)
        fluid_service.update_external_id(id: params[:id], external_id: ship_hero_order_id)

        Result.new(true, { ship_hero_order_id: ship_hero_order_id }, nil)
      rescue StandardError => e
        Result.new(false, nil, "Failed to update order in Fluid: #{e.message}")
      end
    end

    private

    def create_order_in_shiphero
      order_data = build_order_data

      order_query = ShipHero::Mutation::Order.new
      mutation = order_query.create_order(order_data)

      integration_setting = IntegrationSetting.find_by(company_id: company_id)
      graphql_client = ShipHero::GraphqlClient.new(integration_setting)
      graphql_client.execute_query(mutation, { data: order_data })
    end

    def build_order_data
      {
        order_number: params[:order_number],
        shop_name: company_name,
        order_date: params[:created_at],
        total_tax: params[:tax],
        subtotal: params[:subtotal],
        total_price: params[:amount],
        email: params[:email],
        shipping_address: {
          first_name: parse_first_name,
          last_name: parse_last_name,
          company: company_name,
          address1: params.dig(:ship_to, :address1),
          address2: params.dig(:ship_to, :address2),
          city: params.dig(:ship_to, :city),
          state: params.dig(:ship_to, :state),
          state_code: params.dig(:ship_to, :state_code),
          zip: params.dig(:ship_to, :postal_code),
          country: params.dig(:ship_to, :country),
          country_code: params.dig(:ship_to, :country_code),
          email: params[:email],
          phone: params[:phone],
        },
        line_items: build_line_items
      }
    end

    def parse_first_name
      name = params.dig(:ship_to, :name)
      return "" unless name

      name_parts = name.split(" ", 2)
      name_parts.first || ""
    end

    def parse_last_name
      name = params.dig(:ship_to, :name)
      return "" unless name

      name_parts = name.split(" ", 2)
      name_parts.length > 1 ? name_parts.last : ""
    end

    def build_line_items
      params[:items].map do |product|
        {
          sku: product[:sku],
          quantity: product[:quantity],
          price: product[:price].to_s,
          product_name: product[:title],
          option_title: product[:title],
        }
      end
    end

    # Simple result object to match controller expectations
    class Result
      attr_reader :success, :data, :error

      def initialize(success, data, error)
        @success = success
        @data = data
        @error = error
      end

      def success?
        success
      end
    end
  end
end
