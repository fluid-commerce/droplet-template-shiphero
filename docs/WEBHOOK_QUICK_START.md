# ShipHero Webhook Setup - Quick Start

## What You Need

To check and configure ShipHero webhooks, you need:

### 1. API Credentials (Already Stored)
Your ShipHero credentials should already be in the `integration_settings` table:
- Username (ShipHero account email)
- Password (ShipHero account password)
- Access Token (automatically managed)
- Refresh Token (automatically managed)

These are configured when you set up the integration in the admin panel.

### 2. Company ID
Find your company ID:
```bash
# In Rails console
Company.all.pluck(:id, :name)
# Example output: [[1, "My Company"], [2, "Another Company"]]
```

## Quick Commands

### Check if webhooks are configured:
```bash
rake shiphero:webhooks:check[COMPANY_ID]

# Example:
rake shiphero:webhooks:check[1]
```

### See all existing webhooks:
```bash
rake shiphero:webhooks:list[COMPANY_ID]

# Example:
rake shiphero:webhooks:list[1]
```

### Setup webhooks (creates if missing):
```bash
rake shiphero:webhooks:setup[COMPANY_ID]

# Example:
rake shiphero:webhooks:setup[1]
```

## What These Commands Do

1. **Check** - Queries ShipHero API to see if your webhook URL is registered
2. **List** - Shows all webhooks currently in your ShipHero account
3. **Setup** - Creates a new webhook if one doesn't exist for your URL

## Your Webhook URL

The system uses this URL by default:
```
https://fluid-droplet-shiphero-3h47nfle6q-ew.a.run.app/webhook
```

To use a different URL:
```bash
WEBHOOK_URL=https://your-url.com/webhook rake shiphero:webhooks:setup[1]
```

## Behind the Scenes

When you run these commands:

1. **Authentication**: Uses your stored ShipHero credentials
2. **Token Management**: Automatically refreshes expired tokens
3. **GraphQL Queries**: Executes the `webhooks` query or `webhook_create` mutation
4. **Rate Limiting**: Displays credit usage (ShipHero enforces quotas)

## Example Session

```bash
# 1. Check current status
$ rake shiphero:webhooks:check[1]
🔍 Checking webhooks for company 1...
📡 Webhook URL: https://fluid-droplet-shiphero-3h47nfle6q-ew.a.run.app/webhook

⚠️  Webhook is NOT configured
   Webhook URL not found or inactive in ShipHero

Run 'rake shiphero:webhooks:setup[1]' to create the webhook

# 2. Setup the webhook
$ rake shiphero:webhooks:setup[1]
🚀 Setting up webhooks for company 1...
📡 Webhook URL: https://fluid-droplet-shiphero-3h47nfle6q-ew.a.run.app/webhook

✅ Webhook setup successful!

Webhook Details:
  Name:       Fluid Droplet - Order Updates
  ID:         V2ViaG9vazoxMjM0NTY=
  URL:        https://fluid-droplet-shiphero-3h47nfle6q-ew.a.run.app/webhook
  Active:     true
  Request ID: 5f9a8b7c6d5e4f3a2b1c0d9e

🎉 Your integration is now ready to receive ShipHero webhooks!

# 3. Verify it was created
$ rake shiphero:webhooks:list[1]
🔍 Fetching webhooks for company 1...

✅ Found 1 webhook(s):

1. Fluid Droplet - Order Updates
   ID:     V2ViaG9vazoxMjM0NTY=
   URL:    https://fluid-droplet-shiphero-3h47nfle6q-ew.a.run.app/webhook
   Active: ✅ Yes

Request ID:  5f9a8b7c6d5e4f3a2b1c0d9e
Complexity:  51 credits
```

## Troubleshooting

### "No integration setting found for company X"
Make sure the company has ShipHero credentials configured in the admin panel.

### "Failed to authenticate with ShipHero API"
Check that the username/password in integration settings are correct.

### "There are not enough credits"
ShipHero rate limiting - wait a few seconds and try again. The error message tells you how long to wait.

## Next Steps

After webhook setup:
1. The webhook will start receiving ShipHero events
2. Events are automatically routed to the appropriate job (e.g., `OrderShippedJob`)
3. Check your logs to see incoming webhooks
4. Monitor the Event log for processing status

## Full Documentation

See [SHIPHERO_WEBHOOK_SETUP.md](./SHIPHERO_WEBHOOK_SETUP.md) for complete details.

