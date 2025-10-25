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

  # ShipHero webhook events
  # These are triggered when ShipHero sends webhooks to our endpoint
  # Format: webhook_type: "Shipment Update" -> event: "shiphero.shipment.updated"
  EventHandler.register_handler("shiphero.shipment.updated", OrderShippedJob)
  EventHandler.register_handler("shiphero.inventory.updated", InventoryUpdatedJob) if defined?(InventoryUpdatedJob)
  EventHandler.register_handler("shiphero.order.canceled", OrderCanceledJob) if defined?(OrderCanceledJob)

  # Note: Add more ShipHero event handlers as needed
  # Available webhook types from ShipHero:
  # - Shipment Update ✅ (mapped to OrderShippedJob)
  # - Inventory Update
  # - Inventory Change
  # - Order Canceled
  # - Capture Payment
  # - Purchase Order
  # - Return Update
  # - Tote Complete
  # - Tote Cleared
  # - Order Packed Out
  # - Package Added
  # - Print Barcode
  # - Order Allocated
  # - Order Deallocated
  # - Generate Label
  # - Shipment ASN
end
