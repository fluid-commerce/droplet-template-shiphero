module ShipHero
  module Query
    class User

      def me
        <<~GRAPHQL
          query {
            me {
              data {
                id
                email
              }
            }
          }
        GRAPHQL
      end
    end
  end
end
