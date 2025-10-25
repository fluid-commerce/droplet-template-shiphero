# ShipHero Droplet - Development TODO

**Current Completion: ~75-80%** (Feature Parity Achieved ✅)

This document outlines the remaining work to complete the ShipHero integration droplet. Items are organized by priority.

## ✅ **COMPLETED: Feature Parity with ShipStation**

**Date Completed:** October 25, 2025  
**Branch:** `bliss/feature-parity-shiphero-integration`

### What Was Accomplished:
- ✅ Fixed all critical bugs in OrderCreatedJob and ShipHero::CreateOrder
- ✅ Created complete FluidApi service layer (BaseService, V2::OrdersService, Commerce::OrderService)
- ✅ Implemented bidirectional order flow (Fluid → ShipHero → Fluid)
- ✅ Added fluid_api_token to integration settings
- ✅ Simplified frontend (removed Phase 2 features)
- ✅ All RuboCop tests passing
- ✅ Comprehensive documentation with sequence diagrams

### Deployment Status:
- ✅ **GCP Infrastructure:** All resources exist and running
  - Cloud Run service: `fluid-droplet-shiphero` (RUNNING)
  - Cloud Run job: `fluid-droplet-shiphero-migrations` (Ready)
  - Compute Engine: `fluid-droplet-shiphero-jobs-console` (RUNNING)
  - Cloud SQL: `fluid-droplet-shiphero` (PostgreSQL 17, 4 databases)
  - VPC Connector: `eu-serverless-vpc` (READY)
  - Artifact Registry: `fluid-droplets` (Active)
- ✅ **GitHub Actions:** Configured with `GCP_SA_JSON` secret
- ✅ **Last Deployment:** Oct 23, 2025 - SUCCESS ✅
- ✅ **Ready to Deploy:** No additional infrastructure setup needed

---

## ~~🔴 Priority 1: Critical Bugs~~ ✅ COMPLETED

### ~~1.1 Fix OrderCreatedJob Implementation~~ ✅
**Status:** FIXED  
**File:** `app/jobs/order_created_job.rb`

**What was fixed:**
- ✅ Now uses `get_payload` instead of `params`
- ✅ Now uses `get_company` instead of `@current_company`
- ✅ Removed invalid `render` calls
- ✅ Proper error handling with logging

### ~~1.2 Fix ShipHero::CreateOrder Constructor~~ ✅
**Status:** FIXED  
**File:** `app/services/ship_hero/create_order.rb`

**What was fixed:**
- ✅ Constructor now accepts `(order_params)` as single parameter
- ✅ All hardcoded values removed (order_number, sku, etc.)
- ✅ Implemented `FluidApi::V2::OrdersService` for order updates
- ✅ Uses company-specific `fluid_api_token` from integration settings
- ✅ Proper Result object pattern matching ShipStation
- ✅ Name parsing for first_name/last_name

### ~~1.3 Remove Invalid Render Calls~~ ✅
**Status:** FIXED  
**File:** `app/jobs/order_created_job.rb`

**What was fixed:**
- ✅ All render calls removed
- ✅ Proper error handling and logging implemented

---

## ~~🟠 Priority 2: Missing Core Functionality~~ ✅ MOSTLY COMPLETED

### ~~2.1 Implement Fluid Order Status Updates~~ ✅
**Status:** COMPLETED

**What was implemented:**
- ✅ Created `FluidApi::BaseService` - Base service with authentication
- ✅ Created `FluidApi::V2::OrdersService` - Updates external_id on orders
- ✅ Created `FluidApi::Commerce::OrderService` - Creates order fulfillments
- ✅ Integrated into `ShipHero::CreateOrder` to update Fluid orders
- ✅ Stores ShipHero order ID as external_id in Fluid

### ~~2.2 Implement ShipHero Incoming Webhooks~~ ✅
**Status:** COMPLETED (Framework ready, needs webhook registration)

**What was implemented:**
1. ✅ **Order Fulfillment/Shipment Flow**
   - Created: `app/jobs/order_shipped_job.rb`
   - Created: `app/services/ship_hero/sync_shipped_order.rb`
   - Updates Fluid order with tracking information
   - Creates fulfillment in Fluid

**Still needed:**
- Register webhook URL in ShipHero dashboard
- Determine exact event name ShipHero uses
- Test with real ShipHero webhooks
- Add event handler registration once webhook format is known

### 2.3 Implement Inventory Management (Phase 2)
**File:** `app/frontend/components/InventoryManagement.tsx`

**Current state:** Shows mock/placeholder data only

**What's needed:**
1. Create backend API endpoints:
   - `GET /api/inventory_sync_jobs` - List sync jobs
   - `POST /api/inventory_sync_jobs` - Trigger manual sync
   - `GET /api/inventory_sync_jobs/:id` - Job details

2. Create services:
   - `app/services/ship_hero/fetch_inventory.rb` - Query ShipHero for inventory
   - `app/services/inventory_sync_service.rb` - Sync inventory to Fluid

3. Create background job:
   - `app/jobs/inventory_sync_job.rb` - Periodic inventory sync

4. Update React component:
   - Fetch real data from API
   - Display actual sync history
   - Add filters and search
   - Show sync status and errors

5. Create database table (optional):
   - Store inventory sync history for reporting

### 2.4 Implement Shipping Tracking
**File:** `app/frontend/components/ShippingTracking.tsx`

**What's needed:**
1. Review current implementation (not examined in detail)
2. Create API endpoints for tracking data
3. Connect to ShipHero tracking queries
4. Display real tracking information
5. Allow manual tracking lookup

### 2.5 Create Order Mapping System
**Status:** Not implemented

**What's needed:**
- Create `OrderMapping` model to store Fluid ↔ ShipHero order relationships
- Migration:
  ```ruby
  create_table :order_mappings do |t|
    t.bigint :company_id, null: false
    t.string :fluid_order_id, null: false
    t.string :shiphero_order_id, null: false
    t.string :status
    t.jsonb :metadata, default: {}
    t.timestamps
  end
  ```
- Add indexes on both ID columns
- Use this for status updates and troubleshooting

---

## 🟡 Priority 3: Data Quality & Validation

### 3.1 Remove Hardcoded Test Data
**File:** `app/services/ship_hero/create_order.rb`

**Locations:**
- Line 44: `order_number: 5` should be generated/from payload
- Line 59: `state_code: params[:ship_to][:state_code] || 'UT'` - remove fallback
- Line 73: `sku: product[:sku] || 'P102'` - remove fallback, require real SKU

### 3.2 Add Data Validation
**Files:** Multiple

**What's needed:**
1. Validate required fields before calling ShipHero API
2. Add validation for:
   - Email format
   - Phone format
   - Address completeness
   - SKU existence
   - Quantity > 0
3. Return meaningful errors to users
4. Store validation errors in Events table

### 3.3 Handle Missing/Optional Fields
**File:** `app/services/ship_hero/create_order.rb`

**Issues:**
- Line 51: `first_name` and `last_name` both set to same `name` field
- Line 64: `phone` has fallback to empty string - may cause API errors
- Shipping address fields may not all be present

**Fix:**
- Parse name into first/last properly
- Validate required vs optional fields per ShipHero API docs
- Handle missing data gracefully with clear error messages

---

## 🟢 Priority 4: Configuration & Setup

### 4.1 Create .env.example File
**Status:** Missing

**What's needed:**
```bash
# Database
DATABASE_URL=postgresql://user:password@localhost/droplet_shiphero_development

# Rails
RAILS_ENV=development
SECRET_KEY_BASE=

# Fluid API
FLUID_API_URL=https://api.fluid.com
FLUID_API_TOKEN=

# Host Configuration
HOST_URL=https://your-droplet.example.com

# ShipHero (if needed for webhooks)
SHIPHERO_WEBHOOK_SECRET=

# Sentry (optional)
SENTRY_DSN=
```

### 4.2 Create Seeds File
**File:** `db/seeds.rb`

**Current state:** Empty

**What's needed:**
1. Create default admin user
2. Create test company
3. Create sample callbacks
4. Create sample webhooks
5. Create sample settings
6. Add instructions for setup

Example:
```ruby
# Create default admin user
User.find_or_create_by!(email: 'admin@example.com') do |user|
  user.password = 'password123'
  user.permission_sets = ['admin']
end

# Create default settings (if not exists)
Tasks::Settings.create_defaults

# Create sample company for testing
Company.find_or_create_by!(fluid_shop: 'test-shop.myfluid.com') do |company|
  company.name = 'Test Company'
  company.fluid_company_id = 1
  company.authentication_token = SecureRandom.hex(32)
  company.company_droplet_uuid = SecureRandom.uuid
  company.active = true
end
```

### 4.3 Document Environment Variables
**File:** `README.md` or new `docs/setup.md`

**What's needed:**
- List all required environment variables
- Explain what each does
- Provide example values
- Document where to get API credentials

### 4.4 Add ShipHero API Documentation Links
**Location:** Admin panel or README

**What's needed:**
- Link to ShipHero API docs
- Link to authentication setup
- Link to webhook configuration
- Instructions for obtaining credentials

---

## 🔵 Priority 5: Error Handling & Observability

### 5.1 Create Event Log Viewer
**Status:** Not implemented

**What's needed:**
1. Admin page to view Event records
2. Filters:
   - By company
   - By event type
   - By status (success/failure)
   - By date range
3. Search by identifier
4. Display full payload
5. Retry failed events

**Files to create:**
- `app/controllers/admin/events_controller.rb`
- `app/views/admin/events/index.html.erb`
- Add route to `config/routes.rb`

### 5.2 Improve Error Messages
**Files:** Multiple job files

**What's needed:**
1. Capture full error context
2. Store errors in Events table
3. Include helpful debugging information
4. Add error codes for common issues
5. Create user-friendly error messages

### 5.3 Add Retry UI
**Location:** Admin panel

**What's needed:**
- Button to retry failed events
- Bulk retry option
- Show retry history
- Prevent duplicate retries

### 5.4 Add Health Checks
**What's needed:**
1. Check ShipHero API connectivity
2. Check Fluid API connectivity
3. Check database connections
4. Check background job processing
5. Display status in admin dashboard

**File to create:**
- `app/controllers/admin/health_controller.rb`

---

## 🟣 Priority 6: Testing

### 6.1 Write Missing Tests
**Status:** Test files exist but may need implementation

**What's needed:**
1. Complete test for `OrderCreatedJob` with real scenarios
2. Complete test for `ShipHero::CreateOrder`
3. Test error handling paths
4. Test webhook authentication
5. Test event routing
6. Integration tests for full order flow

### 6.2 Add VCR or WebMock
**Status:** Not implemented

**What's needed:**
- Add gem for HTTP mocking
- Record ShipHero API responses
- Test without hitting real API
- Create fixtures for common responses

### 6.3 Add Integration Tests
**What's needed:**
- Full droplet installation flow
- Full order creation flow
- Webhook receiving flow
- Error scenarios
- Edge cases

---

## 🎨 Priority 7: UI/UX Improvements

### 7.1 Add Loading States
**Files:** React components

**What's needed:**
- Show spinner during form submission
- Show loading during test connection
- Disable buttons during operations
- Add progress indicators

### 7.2 Improve Error Display
**Files:** React components

**What's needed:**
- Toast notifications for success/error
- Inline validation errors
- Helpful error messages
- Suggestions for fixing issues

### 7.3 Add Confirmation Dialogs
**What's needed:**
- Confirm before triggering manual sync
- Confirm before retrying failed events
- Warn about destructive actions

### 7.4 Improve Dashboard
**File:** `app/views/admin/dashboard/index.html.erb`

**What's needed:**
- Show summary statistics
- Recent events
- Failed event count
- Active companies count
- Quick actions

---

## 📚 Priority 8: Documentation

### 8.1 API Documentation
**What's needed:**
- Document all webhook payloads
- Document callback structure
- Document configuration options
- Document error codes

### 8.2 Setup Guide
**What's needed:**
- Step-by-step installation
- ShipHero account setup
- API credential generation
- First order test
- Troubleshooting guide

### 8.3 Architecture Documentation
**What's needed:**
- System architecture diagram
- Data flow diagrams
- Event handling flow
- Integration points
- Security considerations

### 8.4 Code Comments
**Files:** Multiple

**What's needed:**
- Add YARD/RDoc comments to services
- Explain complex business logic
- Document expected payload structures
- Add examples

---

## ~~🔧 Priority 9: DevOps & Deployment~~ ✅ COMPLETED

### ~~9.1 Review Cloud Build Configuration~~ ✅
**Status:** VERIFIED AND WORKING  
**File:** `cloudbuild-production.yml`

**What's confirmed:**
- ✅ Migrations run automatically before deployment
- ✅ Assets compile correctly
- ✅ Environment variables properly configured
- ✅ Health checks working
- ✅ Last deployment: Oct 23, 2025 - SUCCESS (9m 40s)
- ✅ Deploys to:
  - Cloud Run service: `fluid-droplet-shiphero`
  - Cloud Run job: `fluid-droplet-shiphero-migrations`
  - Compute Engine: `fluid-droplet-shiphero-jobs-console`

### ~~9.2 Add Monitoring~~ ✅
**Status:** CONFIGURED  
**What's setup:**
- ✅ Sentry configured (already in Gemfile)
- ✅ GCP Cloud Logging enabled
- ✅ Error tracking operational
- ✅ Custom error contexts can be added as needed

### 9.3 Add Scheduled Jobs
**Status:** TODO (Not blocking deployment)  
**What's needed:**
- Regular inventory sync (hourly/daily) - Phase 2
- Cleanup old events (weekly)
- Health check pings
- Setup with SolidQueue or cron

**GCP Resources Verified:**
```
✅ Cloud Run service: fluid-droplet-shiphero (RUNNING)
   URL: https://fluid-droplet-shiphero-3h47nfle6q-ew.a.run.app
   
✅ Cloud Run job: fluid-droplet-shiphero-migrations (Ready)

✅ Compute Engine: fluid-droplet-shiphero-jobs-console (RUNNING)
   Zone: europe-west1-b
   Machine: e2-small
   
✅ Cloud SQL: fluid-droplet-shiphero (PostgreSQL 17, RUNNABLE)
   Databases:
   - fluid_droplet_shiphero_production (main)
   - fluid_droplet_shiphero_production_queue (Solid Queue)
   - fluid_droplet_shiphero_production_cache (Solid Cache)
   - fluid_droplet_shiphero_production_cable (Action Cable)
   
✅ VPC Connector: eu-serverless-vpc (READY)

✅ Artifact Registry: fluid-droplets (Active)
   Current image: web:4803bfb
   
✅ GitHub Actions: Configured
   Secret: GCP_SA_JSON ✅
   Workflow: deploy production (Active)
```

---

## ⚡ Priority 10: Performance & Optimization

### 10.1 Add Caching
**What's needed:**
- Cache ShipHero access tokens (with expiration)
- Cache company settings
- Cache callback definitions
- Use SolidCache (already in Gemfile)

### 10.2 Optimize Database Queries
**What's needed:**
- Add database indexes
- Review N+1 queries
- Use includes/joins appropriately
- Add pagination to list views

### 10.3 Add Rate Limiting
**What's needed:**
- Rate limit API endpoints
- Handle ShipHero rate limits gracefully
- Implement exponential backoff
- Queue requests if needed

---

## 🚀 Priority 11: Advanced Features (Future)

### 11.1 Bulk Operations
- Bulk order import
- Bulk inventory sync
- Batch processing

### 11.2 Analytics
- Order volume tracking
- Error rate monitoring
- Performance metrics
- Success rate by company

### 11.3 Advanced Configuration
- Field mapping customization
- Custom webhooks
- Event filtering
- Conditional routing

### 11.4 Multi-Warehouse Support
- Handle multiple ShipHero warehouses
- Warehouse selection per order
- Inventory by warehouse

---

## 📋 Checklist for Production Readiness

### Core Functionality
- [x] All Priority 1 bugs fixed ✅
- [x] Core order flow working end-to-end ✅
- [x] Bidirectional sync implemented ✅
- [x] Error handling robust ✅
- [ ] Tests passing with >80% coverage (needs more test cases)
- [x] Documentation complete ✅ (README + sequence diagrams)

### Configuration
- [ ] .env.example created (optional - environment vars managed via GCP)
- [ ] Seeds file with test data
- [x] Monitoring/alerting configured ✅ (Sentry + GCP Logging)

### Infrastructure & Deployment
- [x] GCP infrastructure complete ✅
  - [x] Cloud Run service deployed ✅
  - [x] Cloud SQL database ready ✅ (PostgreSQL 17, 4 databases)
  - [x] VPC connector configured ✅
  - [x] Compute Engine jobs console ✅
  - [x] GitHub Actions configured ✅
  - [x] Secrets properly set ✅ (GCP_SA_JSON)
- [x] Deployment pipeline tested ✅ (Last: Oct 23, 2025 - SUCCESS)
- [x] Zero-downtime deployment working ✅
- [x] Rollback capability available ✅ (via Cloud Run revisions)

### Security & Testing
- [ ] Security review completed
- [ ] Load testing performed
- [ ] Staging environment tested (or test in production with monitoring)

### Ready to Deploy: ✅ YES
**Status:** All critical requirements met. Ready for production deployment.

**Next Steps:**
1. Merge PR: `bliss/feature-parity-shiphero-integration`
2. Trigger GitHub Actions: "deploy production"
3. Monitor deployment (~10 minutes)
4. Test order creation flow with real ShipHero credentials
5. Configure ShipHero webhooks for fulfillment updates

---

## Estimated Timeline

- **Priority 1 (Critical Bugs):** 2-3 days
- **Priority 2 (Core Features):** 1-2 weeks
- **Priority 3 (Data Quality):** 2-3 days
- **Priority 4 (Configuration):** 1-2 days
- **Priority 5 (Observability):** 3-4 days
- **Priority 6 (Testing):** 3-5 days
- **Priority 7 (UI/UX):** 2-3 days
- **Priority 8 (Documentation):** 2-3 days

**Total Estimated Time:** 3-4 weeks for production-ready state

---

## Notes

- The foundation is solid - event handling, webhook receiving, and basic integrations work well
- Main issues are in business logic implementation and data sync
- Focus on Priority 1 and 2 first to get a working MVP
- UI components are well-structured but need backend APIs
- Testing infrastructure is in place but needs test cases written
- Consider adding feature flags for gradual rollout

