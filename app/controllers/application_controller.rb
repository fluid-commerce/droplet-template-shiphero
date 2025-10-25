class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  def validate_droplet_authorization
    incoming_uuid = params.dig(:company, :droplet_uuid)
    stored_uuid = Setting.droplet.values["uuid"]

    # Allow first installation if no UUID is stored yet
    return if stored_uuid.blank?

    # Validate UUID matches for subsequent installations
    unless incoming_uuid == stored_uuid
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end

protected

  def after_sign_in_path_for(resource)
    admin_dashboard_index_path
  end

  def current_ability
    @current_ability ||= Ability.new(user: current_user)
  end
end
