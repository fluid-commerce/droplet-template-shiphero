module ShipHero
  module Mutation
    class Order

      def create_order(order_data)
        <<~GRAPHQL
          mutation order_create($data: CreateOrderInput!) {
            order_create(data: $data) {
              order {
                shop_name
                order_date
                total_tax
                subtotal
                total_price
                email
                order_number
                shipping_address {
                  first_name
                  last_name
                  company
                  address1
                  address2
                  city
                  state
                  state_code
                  zip
                  country
                  country_code
                  email
                  phone
                }
                line_items {
                  edges {
                    node {
                      sku
                      quantity
                      price
                      product_name
                      option_title
                    }
                    cursor
                  }
                }
              }
            }
          }
        GRAPHQL
      end
    end
  end
end
