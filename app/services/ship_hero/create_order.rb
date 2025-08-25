module ShipHero
  class CreateOrder
    attr_reader :params, :company_id, :company_name

    def initialize(params)
      # @params = order_params['order'].to_unsafe_h.deep_symbolize_keys[:payload][:order]
      @params = params['order'].to_unsafe_h.deep_symbolize_keys
      @company_id = params['company_id']
      @company_name = Company.find(@company_id)&.name
    end

    def call
      order_response = create_order_in_shiphero

      ship_hero_order_id = order_response.dig("data","order_create","order","id")

      return 'Failed to create order in Ship Hero' unless ship_hero_order_id.present?

      begin
        fluid_service = FluidApi::V2::OrderService.new(ENV.fetch('FLUID_COMPANY_TOKEN', nil))
        fluid_service.update_order(id: params[:id], external_id: ship_hero_order_id)

        return { ship_hero_order_id: ship_hero_order_id }
      rescue StandardError => e
        "Failed to update order in Fluid: #{e.message}"
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
        order_number: 5,
        shop_name: company_name,
        order_date: params[:sale_date],
        total_tax: params[:tax],
        subtotal: params[:subtotal],
        total_price: params[:amount],
        email: params[:email],
        shipping_address: {
          first_name: params[:ship_to][:name],
          last_name: params[:ship_to][:name],
          company: company_name,
          address1: params[:ship_to][:address1],
          address2: '',
          city: params[:ship_to][:city],
          state: params[:ship_to][:state],
          state_code: params[:ship_to][:state_code] || 'UT',
          zip: params[:ship_to][:postal_code],
          country: 'United States',
          country_code: params[:ship_to][:country_code],
          email: params[:email],
          phone: params[:phone] || '',
        },
        line_items: build_line_items
      }
    end

    def build_line_items
      params[:items].map do |product|
        {
          sku: product[:sku] || 'P102',
          # partner_line_item_id: product[:id] || SecureRandom.uuid,
          quantity: product[:quantity] || 1,
          price: product[:price].to_s,
          product_name: product[:title],
          option_title: product[:title],
        }
      end
    end

  end
end
