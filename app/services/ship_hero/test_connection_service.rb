module ShipHero
  class TestConnectionService
    attr_reader :company_id

    def initialize(company_id:)
      @company_id = company_id
    end

    def test_connection
      username = integration_setting.settings["username"]
      password = integration_setting.settings["password"]

      auth_service = ShipHero::AuthenticationService.new(username: username, password: password)
      auth_service_response = auth_service.authenticate

      if auth_service_response["access_token"]
        update_integration_setting(auth_service_response)
        { connection: true, message: "Connection test successful!" }
      else
        { connection: false, message: "Connection test failed!" }
      end
    end

  private

    def integration_setting
      @integration_setting ||= IntegrationSetting.find_by(company_id: company_id)
    end

    def update_integration_setting(auth_service_response)
      expires_in = Time.now + auth_service_response["expires_in"].to_i
      integration_setting.settings = integration_setting.settings.merge({
        expires_in: expires_in,
        refresh_token: auth_service_response["refresh_token"],
      })

      integration_setting.credentials = integration_setting.credentials.merge({
        access_token: auth_service_response["access_token"],
      })

      integration_setting.save!
    end
  end
end
