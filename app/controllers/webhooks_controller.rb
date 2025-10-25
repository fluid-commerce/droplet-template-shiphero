class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :validate_droplet_authorization, if: :is_droplet_installation_event?
  before_action :authenticate_webhook_token, unless: -> { is_droplet_installation_event? || is_shiphero_webhook? }
  before_action :verify_shiphero_webhook, if: :is_shiphero_webhook?

  def create
    # Determine webhook source and route accordingly
    if is_shiphero_webhook?
      handle_shiphero_webhook
    else
      handle_fluid_webhook
    end
  end

private

  def handle_fluid_webhook
    event_type = "#{params[:resource]}.#{params[:event]}"
    version = params[:version]
    payload = params.to_unsafe_h.deep_dup

    if EventHandler.route(event_type, payload, version: version)
      head :accepted
    else
      head :no_content
    end
  end

  def handle_shiphero_webhook
    webhook_type = params[:webhook_type]
    payload = params.to_unsafe_h.deep_dup

    # Map ShipHero webhook types to internal event names
    event_type = map_shiphero_webhook_type(webhook_type)

    if event_type && EventHandler.route(event_type, payload)
      render json: { code: "200", Message: "Success" }
    else
      Rails.logger.warn("Unhandled ShipHero webhook type: #{webhook_type}")
      render json: { code: "200", Message: "Success" }  # Still return success to avoid retries
    end
  end

  def map_shiphero_webhook_type(webhook_type)
    case webhook_type
    when "Shipment Update"
      "shiphero.shipment.updated"
    when "Inventory Update", "Inventory Change"
      "shiphero.inventory.updated"
    when "Order Canceled"
      "shiphero.order.canceled"
    when "Order Packed Out"
      "shiphero.order.packed"
    when "Order Allocated"
      "shiphero.order.allocated"
    when "Order Deallocated"
      "shiphero.order.deallocated"
    when "Return Update"
      "shiphero.return.updated"
    when "Purchase Order"
      "shiphero.purchase_order.updated"
    else
      nil  # Unhandled webhook type
    end
  end

  def is_shiphero_webhook?
    params[:webhook_type].present? && params[:fulfillment].present?
  end

  def verify_shiphero_webhook
    # ShipHero sends x-shiphero-hmac-sha256 header for verification
    # The header in Rack is HTTP_X_SHIPHERO_HMAC_SHA256
    hmac_header = request.headers["HTTP_X_SHIPHERO_HMAC_SHA256"] || request.headers["x-shiphero-hmac-sha256"]

    unless hmac_header
      Rails.logger.warn("ShipHero webhook received without HMAC signature")
      render json: { error: "Missing HMAC signature" }, status: :unauthorized
      return
    end

    # Get the webhook secret for verification
    # The secret is stored when the webhook is created
    webhook_type = params[:webhook_type]
    webhook_secret = get_shiphero_webhook_secret(webhook_type)

    unless webhook_secret
      Rails.logger.error("No webhook secret found for webhook type: #{webhook_type}")
      # Still accept for now to avoid breaking existing webhooks
      # TODO: Make this strict after migration period
      return
    end

    # Verify HMAC signature
    request_body = request.raw_post
    calculated_hmac = calculate_hmac_signature(webhook_secret, request_body)

    unless secure_compare(calculated_hmac, hmac_header)
      Rails.logger.error("ShipHero webhook HMAC verification failed")
      Rails.logger.error("Expected: #{calculated_hmac}")
      Rails.logger.error("Received: #{hmac_header}")
      render json: { error: "Invalid HMAC signature" }, status: :unauthorized
    end
  end

  def get_shiphero_webhook_secret(webhook_type)
    # Try to find the company from warehouse or order data
    # For now, use default secret from settings
    # TODO: Implement company-specific secret lookup
    Setting.shiphero_webhook&.default_secret || ENV["SHIPHERO_WEBHOOK_SECRET"]
  end

  def calculate_hmac_signature(secret, data)
    require "openssl"
    require "base64"

    digest = OpenSSL::HMAC.digest("SHA256", secret, data)
    Base64.strict_encode64(digest)
  end

  def secure_compare(a, b)
    return false if a.blank? || b.blank? || a.bytesize != b.bytesize

    l = a.unpack "C#{a.bytesize}"
    r = 0
    i = -1

    b.each_byte { |byte| r |= byte ^ l[i += 1] }
    r == 0
  end

  def is_droplet_installation_event?
    params[:resource] == "droplet" && %w[installed uninstalled].include?(params[:event])
  end

  def authenticate_webhook_token
    company = find_company
    if company.blank?
      render json: { error: "Company not found" }, status: :not_found
    elsif !valid_auth_token?(company)
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end

  def valid_auth_token?(company)
    # Check header auth token first, then fall back to params
    auth_header = request.headers["AUTH_TOKEN"] || request.headers["X-Auth-Token"] || request.env["HTTP_AUTH_TOKEN"]
    webhook_auth_token = Setting.fluid_webhook.auth_token

    auth_header.present? && [ webhook_auth_token, company.webhook_verification_token ].include?(auth_header)
  end

  def find_company
    Company.find_by(fluid_company_id: company_params[:fluid_company_id])
  end

  def company_params
    params.require(:company).permit(
      :company_droplet_uuid,
      :droplet_installation_uuid,
      :fluid_company_id,
      :webhook_verification_token,
      :authentication_token
    )
  end
end
