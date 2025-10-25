# frozen_string_literal: true

namespace :shiphero do
  desc "Test ShipHero API connection and display account info"
  task :test_connection, [ :company_id ] => :environment do |_t, args|
    company_id = args[:company_id] || ENV["COMPANY_ID"]

    unless company_id
      puts "❌ Error: Please provide a company_id"
      puts "Usage: rake shiphero:test_connection[COMPANY_ID]"
      puts "   or: COMPANY_ID=123 rake shiphero:test_connection"
      exit 1
    end

    puts "🔌 Testing ShipHero API connection for company #{company_id}..."
    puts

    begin
      company = Company.find(company_id)
      puts "Company: #{company.name}"
      puts

      integration_setting = IntegrationSetting.find_by(company_id: company_id)

      unless integration_setting
        puts "❌ No integration setting found for this company"
        puts "   Please configure ShipHero credentials in the admin panel first"
        exit 1
      end

      puts "Integration Settings:"
      puts "  Username:       #{integration_setting.settings['username'] ? '✅ Set' : '❌ Missing'}"
      puts "  Password:       #{integration_setting.settings['password'] ? '✅ Set' : '❌ Missing'}"
      puts "  Store Name:     #{integration_setting.settings['store_name'] || 'Not set'}"
      puts "  Warehouse:      #{integration_setting.settings['warehouse_name'] || 'Not set'}"
      puts "  Fluid API Token: #{integration_setting.settings['fluid_api_token'] ? '✅ Set' : '❌ Missing'}"
      puts

      # Test authentication
      puts "🔐 Testing authentication..."
      client = ShipHero::GraphqlClient.new(integration_setting: integration_setting)
      result = client.test_connection

      if result[:connection]
        puts "✅ Authentication successful!"
        puts

        if result[:data]
          puts "Account Information:"
          puts "  Email:    #{result[:data]['email']}"
          puts "  Name:     #{result[:data]['first_name']} #{result[:data]['last_name']}"
          puts "  ID:       #{result[:data]['id']}"
        end

        puts
        puts "✅ All systems operational!"
        puts
        puts "Next steps:"
        puts "1. Run: rake shiphero:webhooks:check[#{company_id}]"
        puts "2. Run: rake shiphero:webhooks:setup[#{company_id}]"
      else
        puts "❌ Connection failed!"
        puts "   #{result[:message]}"

        if result[:errors]
          puts
          puts "Errors:"
          result[:errors].each do |error|
            puts "  - #{error['message']}"
          end
        end
        exit 1
      end
    rescue ActiveRecord::RecordNotFound => e
      puts "❌ Company not found: #{e.message}"
      puts
      puts "Available companies:"
      Company.all.each do |c|
        puts "  #{c.id}: #{c.name}"
      end
      exit 1
    rescue StandardError => e
      puts "❌ Error: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end

  desc "Show ShipHero account quota/rate limit status"
  task :quota, [ :company_id ] => :environment do |_t, args|
    company_id = args[:company_id] || ENV["COMPANY_ID"]

    unless company_id
      puts "❌ Error: Please provide a company_id"
      puts "Usage: rake shiphero:quota[COMPANY_ID]"
      exit 1
    end

    puts "📊 Fetching ShipHero API quota for company #{company_id}..."
    puts

    begin
      integration_setting = IntegrationSetting.find_by(company_id: company_id)
      raise "No integration setting found" unless integration_setting

      client = ShipHero::GraphqlClient.new(integration_setting: integration_setting)

      query = <<~GRAPHQL
        query {
          user_quota {
            credits_remaining
            max_available
            increment_rate
          }
        }
      GRAPHQL

      response = client.execute_query(query)

      if response["errors"]
        puts "❌ Error fetching quota:"
        response["errors"].each do |error|
          puts "  - #{error['message']}"
        end
        exit 1
      end

      quota = response.dig("data", "user_quota")

      if quota
        credits_remaining = quota["credits_remaining"]
        max_available = quota["max_available"]
        increment_rate = quota["increment_rate"]
        percentage = (credits_remaining.to_f / max_available.to_f * 100).round(1)

        puts "✅ Rate Limit Status:"
        puts
        puts "  Credits Remaining:  #{credits_remaining} / #{max_available} (#{percentage}%)"
        puts "  Increment Rate:     +#{increment_rate} credits/second"
        puts

        if percentage < 10
          puts "⚠️  WARNING: Low on credits! Consider waiting before making more requests."
        elsif percentage < 30
          puts "⚡ Credits are running low. Requests may be throttled soon."
        else
          puts "✅ Healthy credit balance."
        end
      else
        puts "❌ Could not fetch quota information"
      end
    rescue StandardError => e
      puts "❌ Error: #{e.message}"
      exit 1
    end
  end

  desc "Show all available ShipHero rake tasks"
  task :help do
    puts <<~HELP
      ShipHero Integration - Available Tasks
      ======================================

      Connection & Testing:
      ---------------------
      rake shiphero:test_connection[COMPANY_ID]
        Test API connection and display account info

      rake shiphero:quota[COMPANY_ID]
        Show current rate limit status

      Webhook Management:
      -------------------
      rake shiphero:webhooks:check[COMPANY_ID]
        Check if webhooks are configured

      rake shiphero:webhooks:list[COMPANY_ID]
        List all webhooks in ShipHero

      rake shiphero:webhooks:setup[COMPANY_ID]
        Setup webhooks (creates if missing)

      rake shiphero:webhooks:delete[COMPANY_ID,WEBHOOK_ID]
        Delete a specific webhook

      rake shiphero:webhooks:help
        Detailed webhook management help

      Help:
      -----
      rake shiphero:help
        Show this help message

      Examples:
      ---------
      # Test connection for company 1
      rake shiphero:test_connection[1]

      # Check quota status
      rake shiphero:quota[1]

      # Setup webhooks
      rake shiphero:webhooks:setup[1]

      # List all webhooks
      rake shiphero:webhooks:list[1]

      Environment Variables:
      ----------------------
      COMPANY_ID    - Company ID to use
      WEBHOOK_URL   - Custom webhook URL (optional)

    HELP
  end
end
