module ShipHero
  class AuthenticationService
    attr_reader :username, :password, :refresh_token

    BASE_URL = "https://public-api.shiphero.com"

    def initialize(username:, password:, refresh_token: nil)
      @username = username
      @password = password
      @refresh_token = refresh_token
    end

    def authenticate
      response = HTTParty.post(
        "#{BASE_URL}/auth/token",
        body: { username: username, password: password }
      )

      response.parsed_response
    end

    def refresh_token
      response = HTTParty.post(
        "#{BASE_URL}/auth/refresh",
        body: { refresh_token: refresh_token }
      )

      response.parsed_response
    end
  end
end
