# frozen_string_literal: true

namespace :shiphero do
  namespace :webhooks do
    desc "List all webhooks configured in ShipHero for a company"
    task :list, [ :company_id ] => :environment do |_t, args|
      company_id = args[:company_id] || ENV["COMPANY_ID"]

      unless company_id
        puts "❌ Error: Please provide a company_id"
        puts "Usage: rake shiphero:webhooks:list[COMPANY_ID]"
        puts "   or: COMPANY_ID=123 rake shiphero:webhooks:list"
        exit 1
      end

      puts "🔍 Fetching webhooks for company #{company_id}..."
      puts

      begin
        service = ShipHero::WebhookService.new(company_id: company_id)
        result = service.list_webhooks

        if result[:success]
          webhooks = result[:webhooks]

          if webhooks.empty?
            puts "📭 No webhooks configured in ShipHero"
          else
            puts "✅ Found #{webhooks.count} webhook(s):"
            puts
            webhooks.each_with_index do |webhook, index|
              puts "#{index + 1}. #{webhook['name']}"
              puts "   ID:     #{webhook['id']}"
              puts "   URL:    #{webhook['url']}"
              puts "   Active: #{webhook['active'] ? '✅ Yes' : '❌ No'}"
              puts
            end
          end

          puts "Request ID:  #{result[:request_id]}"
          puts "Complexity:  #{result[:complexity]} credits"
        else
          puts "❌ Error fetching webhooks:"
          result[:errors].each do |error|
            puts "  - #{error['message']}"
          end
          exit 1
        end
      rescue StandardError => e
        puts "❌ Error: #{e.message}"
        puts e.backtrace.first(5).join("\n")
        exit 1
      end
    end

    desc "Check if required webhooks are configured for a company"
    task :check, [ :company_id ] => :environment do |_t, args|
      company_id = args[:company_id] || ENV["COMPANY_ID"]
      webhook_url = ENV["WEBHOOK_URL"] || "https://fluid-droplet-shiphero-3h47nfle6q-ew.a.run.app/webhook"

      unless company_id
        puts "❌ Error: Please provide a company_id"
        puts "Usage: rake shiphero:webhooks:check[COMPANY_ID]"
        puts "   or: COMPANY_ID=123 rake shiphero:webhooks:check"
        exit 1
      end

      puts "🔍 Checking webhooks for company #{company_id}..."
      puts "📡 Webhook URL: #{webhook_url}"
      puts

      begin
        service = ShipHero::WebhookService.new(company_id: company_id)
        result = service.check_required_webhooks(webhook_url: webhook_url)

        if result[:configured]
          puts "✅ Webhook is configured!"
          puts
          puts "Webhook Details:"
          puts "  Name:   #{result[:webhook]['name']}"
          puts "  ID:     #{result[:webhook]['id']}"
          puts "  URL:    #{result[:webhook]['url']}"
          puts "  Active: #{result[:webhook]['active']}"
        else
          puts "⚠️  Webhook is NOT configured"
          puts "   #{result[:message]}"
          puts
          if result[:all_webhooks]&.any?
            puts "Existing webhooks in ShipHero:"
            result[:all_webhooks].each_with_index do |webhook, index|
              puts "  #{index + 1}. #{webhook['name']} - #{webhook['url']} (Active: #{webhook['active']})"
            end
            puts
          end
          puts "Run 'rake shiphero:webhooks:setup[#{company_id}]' to create the webhook"
        end
      rescue StandardError => e
        puts "❌ Error: #{e.message}"
        puts e.backtrace.first(5).join("\n")
        exit 1
      end
    end

    desc "Setup required webhooks for a company"
    task :setup, [ :company_id ] => :environment do |_t, args|
      company_id = args[:company_id] || ENV["COMPANY_ID"]
      webhook_url = ENV["WEBHOOK_URL"] || "https://fluid-droplet-shiphero-3h47nfle6q-ew.a.run.app/webhook"

      unless company_id
        puts "❌ Error: Please provide a company_id"
        puts "Usage: rake shiphero:webhooks:setup[COMPANY_ID]"
        puts "   or: COMPANY_ID=123 rake shiphero:webhooks:setup"
        puts
        puts "Optional: Set custom webhook URL with WEBHOOK_URL environment variable"
        exit 1
      end

      puts "🚀 Setting up webhooks for company #{company_id}..."
      puts "📡 Webhook URL: #{webhook_url}"
      puts

      begin
        service = ShipHero::WebhookService.new(company_id: company_id)
        result = service.setup_webhooks(webhook_url: webhook_url)

        if result[:success]
          puts "✅ Webhook setup successful!"
          puts
          puts "Webhook Details:"
          puts "  Name:       #{result[:webhook]['name']}"
          puts "  ID:         #{result[:webhook]['id']}"
          puts "  URL:        #{result[:webhook]['url']}"
          puts "  Shop Name:  #{result[:webhook]['shop_name']}"
          puts "  Source:     #{result[:webhook]['source']}"
          puts "  Request ID: #{result[:request_id]}" if result[:request_id]
          puts
          if result[:shared_signature_secret]
            puts "🔐 IMPORTANT: Webhook Secret (save this - only shown once!):"
            puts "   #{result[:shared_signature_secret]}"
            puts
            puts "   This secret has been automatically stored in your integration settings."
            puts "   It will be used to verify incoming webhooks from ShipHero."
            puts
          end
          puts "🎉 Your integration is now ready to receive ShipHero webhooks!"
        else
          puts "❌ Failed to setup webhook:"
          if result[:errors]
            result[:errors].each do |error|
              puts "  - #{error['message']}"
            end
          else
            puts "  #{result[:message]}"
          end
          exit 1
        end
      rescue StandardError => e
        puts "❌ Error: #{e.message}"
        puts e.backtrace.first(5).join("\n")
        exit 1
      end
    end

    desc "Delete a webhook from ShipHero"
    task :delete, %i[company_id webhook_name] => :environment do |_t, args|
      company_id = args[:company_id] || ENV["COMPANY_ID"]
      webhook_name = args[:webhook_name] || ENV["WEBHOOK_NAME"]
      shop_name = ENV["SHOP_NAME"] || "fluid-droplet"

      unless company_id && webhook_name
        puts "❌ Error: Please provide both company_id and webhook_name"
        puts "Usage: rake shiphero:webhooks:delete[COMPANY_ID,WEBHOOK_NAME]"
        puts "   or: COMPANY_ID=123 WEBHOOK_NAME=\"Shipment Update\" rake shiphero:webhooks:delete"
        puts
        puts "Optional: SHOP_NAME=fluid-droplet (defaults to 'fluid-droplet')"
        exit 1
      end

      puts "🗑️  Deleting webhook '#{webhook_name}' for company #{company_id}..."
      puts

      begin
        service = ShipHero::WebhookService.new(company_id: company_id)
        result = service.delete_webhook(name: webhook_name, shop_name: shop_name)

        if result[:success]
          puts "✅ Webhook deleted successfully!"
          puts "   Request ID: #{result[:request_id]}"
        else
          puts "❌ Failed to delete webhook:"
          result[:errors].each do |error|
            puts "  - #{error['message']}"
          end
          exit 1
        end
      rescue StandardError => e
        puts "❌ Error: #{e.message}"
        puts e.backtrace.first(5).join("\n")
        exit 1
      end
    end

    desc "Show usage examples"
    task :help do
      puts <<~HELP
        ShipHero Webhook Management Tasks
        ==================================

        Available tasks:

        1. List all webhooks:
           rake shiphero:webhooks:list[COMPANY_ID]
           or: COMPANY_ID=123 rake shiphero:webhooks:list

        2. Check if webhooks are configured:
           rake shiphero:webhooks:check[COMPANY_ID]
           or: COMPANY_ID=123 rake shiphero:webhooks:check

        3. Setup webhooks (creates if not exists):
           rake shiphero:webhooks:setup[COMPANY_ID]
           or: COMPANY_ID=123 rake shiphero:webhooks:setup

        4. Delete a webhook:
           rake shiphero:webhooks:delete[COMPANY_ID,WEBHOOK_ID]
           or: COMPANY_ID=123 WEBHOOK_ID=abc123 rake shiphero:webhooks:delete

        Environment Variables:
        ----------------------
        COMPANY_ID    - The ID of the company in your database
        WEBHOOK_URL   - Custom webhook URL (defaults to production URL)
        WEBHOOK_ID    - The ShipHero webhook ID to delete

        Examples:
        ---------
        # List webhooks for company 1
        rake shiphero:webhooks:list[1]

        # Check webhook configuration with custom URL
        WEBHOOK_URL=https://my-custom-url.com/webhook rake shiphero:webhooks:check[1]

        # Setup webhooks for company 1
        rake shiphero:webhooks:setup[1]

      HELP
    end
  end
end
