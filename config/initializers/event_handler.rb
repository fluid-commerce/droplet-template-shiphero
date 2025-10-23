# frozen_string_literal: true

# Register default webhook event handlers.
#
# This is inside a to_prepare block which runs after all application code
# is loaded, making sure the constants are defined when this runs.
# It also runs on every code reload in development, ensuring the handlers
# are always registered.
Rails.application.config.to_prepare do
  # Fluid Droplet lifecycle events
  EventHandler.register_handler("droplet.uninstalled", DropletUninstalledJob)
  EventHandler.register_handler("droplet.installed", DropletInstalledJob)

  # Fluid order events
  EventHandler.register_handler("order.created", OrderCreatedJob)

  # TODO: Register ShipHero webhook events once webhook is configured
  # ShipHero sends webhooks for shipment updates. You will need to:
  # 1. Configure ShipHero webhook URL in their dashboard (pointing to your webhook endpoint)
  # 2. Determine the exact event name ShipHero uses (e.g., "shipment.created", "order.shipped")
  # 3. Register the handler here, for example:
  # EventHandler.register_handler("shiphero.order.shipped", OrderShippedJob)
  #
  # Note: ShipHero webhooks will come to the same webhook endpoint but with different
  # authentication and payload structure than Fluid webhooks.
end
