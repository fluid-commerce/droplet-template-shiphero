class DropletInstalledJob < WebhookEventJob
  # payload - Hash received from the webhook controller.
  # Expected structure (example):
  # {
  #   "company" => {
  #     "fluid_shop" => "example.myshopify.com",
  #     "name" => "Example Shop",
  #     "fluid_company_id" => 123,
  #     "company_droplet_uuid" => "uuid",
  #     "authentication_token" => "token",
  #     "webhook_verification_token" => "verify",
  #   }
  # }
  def process_webhook
    # Validate required keys in payload
    validate_payload_keys("company")
    company_attributes = get_payload.fetch("company", {})

    # Store droplet UUID on first installation
    store_droplet_uuid_if_needed(company_attributes["droplet_uuid"])

    company = Company.find_by(fluid_shop: company_attributes["fluid_shop"]) || Company.new

    company.assign_attributes(company_attributes.slice(
      "fluid_shop",
      "name",
      "fluid_company_id",
      "authentication_token",
      "webhook_verification_token",
      "droplet_installation_uuid"
    ))
    company.company_droplet_uuid = company_attributes.fetch("droplet_uuid")
    company.active = true

    unless company.save
      Rails.logger.error(
        "[DropletInstalledJob] Failed to create company: #{company.errors.full_messages.join(', ')}"
      )
      return
    end

    register_active_callbacks(company)
  end

private

  def store_droplet_uuid_if_needed(droplet_uuid)
    droplet_setting = Setting.droplet
    
    # Only update if UUID is not already set
    if droplet_setting.values["uuid"].blank? && droplet_uuid.present?
      droplet_setting.values = droplet_setting.values.merge("uuid" => droplet_uuid)
      droplet_setting.save!
      Rails.logger.info("[DropletInstalledJob] Stored droplet UUID: #{droplet_uuid}")
    end
  end

  def register_active_callbacks(company)
    client = FluidClient.new(company.authentication_token)
    active_callbacks = ::Callback.active
    installed_callback_ids = []

    active_callbacks.each do |callback|
      begin
        callback_attributes = {
          definition_name: callback.name,
          url: callback.url,
          timeout_in_seconds: callback.timeout_in_seconds,
          active: true,
        }

        response = client.callback_registrations.create(callback_attributes)
        if response && response["callback_registration"]["uuid"]
          installed_callback_ids << response["callback_registration"]["uuid"]
        else
          Rails.logger.warn(
            "[DropletInstalledJob] Callback registered but no UUID returned for: #{callback.name}"
          )
        end
      rescue => e
        Rails.logger.error(
          "[DropletInstalledJob] Failed to register callback #{callback.name}: #{e.message}"
        )
      end
    end

    if installed_callback_ids.any?
      company.update(installed_callback_ids: installed_callback_ids)
    end
  end
end
