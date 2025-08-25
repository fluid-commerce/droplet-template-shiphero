class IntegrationSettingsController < ApplicationController
  def create
    integration_setting = IntegrationSetting.find_or_initialize_by(company_id: integration_setting_params[:company_id])

    integration_setting.settings = integration_setting.settings.merge({
      store_name: integration_setting_params[:store_name],
      warehouse_name: integration_setting_params[:warehouse_name],
      username: integration_setting_params[:username],
      password: integration_setting_params[:password],
    })

    integration_setting.save!

    render json: integration_setting, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def test_connection
    test_connection_service = ShipHero::TestConnectionService.new(company_id: params[:company_id])
    test_connection_response = test_connection_service.test_connection

    if test_connection_response[:connection]
      render json: test_connection_response, status: :ok
    else
      render json: test_connection_response, status: :unprocessable_entity
    end
  end

private

  def integration_setting_params
    params.require(:integration_setting).permit(:company_id, :store_name, :warehouse_name, :username, :password)
  end
end
