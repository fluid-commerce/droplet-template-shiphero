# VPC Networking Guide for Fluid Droplets

This document explains the VPC (Virtual Private Cloud) networking configuration used for Fluid Droplet services and how to replicate it for other services.

## Overview

The Fluid infrastructure uses a custom VPC network (`fluid-egress-vpc`) for secure communication between serverless services (Cloud Run) and managed databases (Cloud SQL).

## Network Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Internet / External APIs                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Cloud Run Service                          │
│            fluid-droplet-shiphero (HTTPS)                    │
│                                                              │
│  • Auto-scaling: 1-3 instances                              │
│  • CPU: 1000m, Memory: 2Gi                                  │
│  • Network: fluid-egress-vpc                                │
│  • Subnet: fluid-egress-vpc (10.132.0.0/20)                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ Private IP
                              │ (via VPC network interface)
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  Cloud SQL PostgreSQL                        │
│         fluid-droplet-shiphero (PostgreSQL 17)              │
│                                                              │
│  • Private IP: Connected via fluid-egress-vpc               │
│  • Public IP: 35.240.27.99 (authorized networks only)       │
│  • 4 Databases: main, queue, cache, cable                   │
└─────────────────────────────────────────────────────────────┘
```

## Current VPC Configuration

### VPC Networks

**Project ID:** `fluid-417204`

**Available VPC Networks:**

1. **default** (Legacy, AUTO mode)
   - BGP Routing: REGIONAL
   - Auto-creates subnets in each region
   - Used by: VPC Connector (legacy)

2. **fluid-egress-vpc** (Production, AUTO mode) ⭐
   - BGP Routing: GLOBAL
   - Covers all GCP regions globally
   - Used by: All production Cloud Run services

### VPC Subnets

The `fluid-egress-vpc` network has subnets in all GCP regions:

| Region | Subnet CIDR | Purpose |
|--------|-------------|---------|
| europe-west1 (Belgium) | 10.132.0.0/20 | **Primary - Droplets** |
| us-central1 (Iowa) | 10.128.0.0/20 | Secondary |
| europe-west1 (Worker) | 172.16.0.0/24 | Compute Engine workers |
| _...and 40+ more regions_ | 10.x.0.0/20 | Global coverage |

**Key Subnet for Droplets:**
- **Name:** `fluid-egress-vpc` (europe-west1)
- **CIDR:** `10.132.0.0/20`
- **Usable IPs:** 4,094 addresses
- **Purpose:** Cloud Run services in Europe

### VPC Connector (Legacy)

> **Note:** VPC Connector is a legacy approach. Modern Cloud Run uses Direct VPC Egress (network interfaces) instead.

**Connector:** `eu-serverless-vpc`
- **Network:** default
- **IP Range:** 10.8.0.0/28 (16 IPs, 14 usable)
- **Machine Type:** e2-standard-4
- **Instances:** 5 min, 10 max
- **Throughput:** 500-1000 Mbps
- **Status:** READY
- **Used by:** Older services (being phased out)

## How Cloud Run Connects to Cloud SQL

### Method: Direct VPC Egress (Current Approach)

Cloud Run services use **Direct VPC Egress** with network interfaces:

```yaml
annotations:
  run.googleapis.com/network-interfaces: '[{"network":"fluid-egress-vpc","subnetwork":"fluid-egress-vpc"}]'
  run.googleapis.com/vpc-access-egress: all-traffic
  run.googleapis.com/cloudsql-instances: fluid-417204:europe-west1:fluid-droplet-shiphero
```

**Benefits:**
- ✅ Direct network interface (no intermediary connector)
- ✅ Better performance and lower latency
- ✅ Lower cost (no VPC Connector instances)
- ✅ Scales automatically with Cloud Run
- ✅ Private communication to Cloud SQL

### Configuration Details

**Cloud Run Service Settings:**
- **VPC Network:** `fluid-egress-vpc`
- **Subnet:** `fluid-egress-vpc` (europe-west1)
- **Egress:** `all-traffic` (all egress goes through VPC)
- **Cloud SQL Connection:** Via Cloud SQL Proxy over private IP

**Cloud SQL Settings:**
- **Public IP:** 35.240.27.99 (restricted by authorized networks)
- **Authorized Networks:** NAT IP (34.79.50.135)
- **SSL:** Optional (ALLOW_UNENCRYPTED_AND_ENCRYPTED)
- **Private Path:** Not enabled (uses public IP with authorization)

## Setting Up VPC for a New Droplet

### Prerequisites

✅ Already created and available:
- VPC Network: `fluid-egress-vpc`
- Subnet in europe-west1: `10.132.0.0/20`
- Service Account with proper permissions

### Step 1: Configure Cloud SQL Instance

When creating a new Cloud SQL instance via Terraform:

```hcl
resource "google_sql_database_instance" "instance" {
  name             = "fluid-droplet-yourservice"
  database_version = "POSTGRES_17"
  region           = "europe-west1"

  settings {
    tier = "db-custom-1-3840"
    
    ip_configuration {
      ipv4_enabled = true
      require_ssl  = false
      
      # Add authorized network for NAT egress
      authorized_networks {
        name  = "nat-europe"
        value = "34.79.50.135"  # Shared NAT IP
      }
    }
  }
}
```

### Step 2: Configure Cloud Run Service

In your Terraform module:

```hcl
module "cloud_run_service" {
  source = "../../modules/cloud_run"

  service_name = "fluid-droplet-yourservice"
  region       = "europe-west1"

  # VPC Configuration
  vpc_network_app = "fluid-egress-vpc"
  vpc_subnet_app  = "fluid-egress-vpc"  # subnet in europe-west1

  # Cloud SQL Connection
  cloud_sql_instances = [
    "fluid-417204:europe-west1:fluid-droplet-yourservice"
  ]

  # Scaling
  max_instances = 3
  min_instances = 1

  # Resources
  resource_limits_cpu    = "1000m"
  resource_limits_memory = "2Gi"
}
```

### Step 3: Set Environment Variables

Configure database connection via environment variable:

```bash
DATABASE_URL=postgresql://username:password@/database?host=/cloudsql/fluid-417204:europe-west1:fluid-droplet-yourservice
```

The `/cloudsql/` prefix uses the Cloud SQL Proxy automatically available in Cloud Run.

### Step 4: Deploy

Deploy via Cloud Build:

```bash
gcloud beta builds submit \
  --config cloudbuild-production.yml \
  --region=europe-west1 \
  --project=fluid-417204 .
```

## Verification Commands

### Check VPC Configuration

```bash
# List VPC networks
gcloud compute networks list

# List subnets in fluid-egress-vpc
gcloud compute networks subnets list --network=fluid-egress-vpc

# Check VPC connector (legacy)
gcloud compute networks vpc-access connectors describe eu-serverless-vpc \
  --region=europe-west1
```

### Check Cloud Run Service

```bash
# Describe service
gcloud run services describe fluid-droplet-shiphero \
  --region=europe-west1 \
  --format="yaml(spec.template.metadata.annotations)"

# Check network interfaces
gcloud run services describe fluid-droplet-shiphero \
  --region=europe-west1 \
  --format="value(spec.template.metadata.annotations.'run.googleapis.com/network-interfaces')"
```

### Check Cloud SQL Connectivity

```bash
# Describe Cloud SQL instance
gcloud sql instances describe fluid-droplet-shiphero \
  --format="yaml(ipAddresses,settings.ipConfiguration)"

# Test connection from Cloud Run (in rails console)
docker exec -it $(docker ps -q | head -n 1) bin/rails c
> ActiveRecord::Base.connection.execute("SELECT 1")
```

## Troubleshooting

### Issue: Cloud Run can't connect to Cloud SQL

**Check:**
1. Cloud SQL instance is RUNNABLE
2. Cloud SQL connection string in Cloud Run annotations
3. Database URL format uses `/cloudsql/` prefix
4. Service account has `cloudsql.client` role

```bash
# Check Cloud SQL status
gcloud sql instances list

# Check service account roles
gcloud projects get-iam-policy fluid-417204 \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:YOUR_SA@"
```

### Issue: High latency to database

**Check:**
1. Cloud Run and Cloud SQL in same region (europe-west1)
2. Using Direct VPC Egress (not legacy VPC Connector)
3. Connection pooling configured properly

### Issue: Connection timeouts

**Possible causes:**
- Firewall rules blocking traffic
- Incorrect subnet configuration
- Cloud SQL authorized networks not including NAT IP

## Security Considerations

### Network Security

✅ **Implemented:**
- VPC isolates services from public internet
- Cloud SQL only accessible via authorized networks
- TLS encryption available (optional)
- Service accounts with least-privilege access

### Best Practices

1. **Use Direct VPC Egress** - Better performance than VPC Connector
2. **Keep services in same region** - europe-west1 for lower latency
3. **Enable SSL for Cloud SQL** - For production databases with sensitive data
4. **Use Secret Manager** - For database credentials (don't hardcode)
5. **Monitor egress traffic** - Set up Cloud Monitoring alerts

## Cost Optimization

### Current Costs

**VPC Network:** Free (no data transfer within same region)

**VPC Connector (if used):** ~$45-90/month
- Based on: e2-standard-4 × 5-10 instances
- **Recommendation:** Migrate to Direct VPC Egress

**Direct VPC Egress:** Free
- No per-instance charges
- Only standard Cloud Run costs

**Data Transfer:**
- Same region: Free
- Cross-region: $0.01/GB

### Cost Savings

Migrating from VPC Connector to Direct VPC Egress:
- **Save:** $45-90/month per service
- **Performance:** Improved latency
- **Scalability:** Better auto-scaling

## Migration Guide: VPC Connector → Direct VPC Egress

If you have a service using the legacy `eu-serverless-vpc` connector:

### Update Cloud Run Configuration

```bash
gcloud run services update YOUR_SERVICE \
  --region=europe-west1 \
  --network=fluid-egress-vpc \
  --subnet=fluid-egress-vpc \
  --vpc-egress=all-traffic \
  --clear-vpc-connector
```

### Update Terraform

```hcl
# Remove this:
# vpc_connector = "eu-serverless-vpc"

# Add this:
vpc_network_app = "fluid-egress-vpc"
vpc_subnet_app  = "fluid-egress-vpc"
```

## References

- [Cloud Run VPC Documentation](https://cloud.google.com/run/docs/configuring/vpc-direct-vpc)
- [Cloud SQL Private IP](https://cloud.google.com/sql/docs/postgres/private-ip)
- [VPC Network Overview](https://cloud.google.com/vpc/docs/vpc)

## Summary

**For New Droplets:**
1. Use `fluid-egress-vpc` network (already exists)
2. Use `fluid-egress-vpc` subnet in europe-west1
3. Configure Direct VPC Egress (not VPC Connector)
4. Connect to Cloud SQL via Cloud SQL Proxy
5. Use same region (europe-west1) for lowest latency

**Key Configuration:**
```yaml
Network: fluid-egress-vpc
Subnet: fluid-egress-vpc (10.132.0.0/20)
Region: europe-west1
Egress: all-traffic
```

This setup is already tested and working with fluid-droplet-shiphero! 🚀

