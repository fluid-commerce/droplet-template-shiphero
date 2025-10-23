class OrderCreatedJob < WebhookEventJob
  def process_webhook
    create_order_service = ShipHero::CreateOrder.new(get_payload)
    create_order_service.call
  rescue StandardError => e
    Rails.logger.error("Error creating order: #{e.message}")
  end
end
