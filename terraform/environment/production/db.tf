# Cloud SQL PostgreSQL instance
module "postgres_db_instance" {
  source = "../../modules/cloud_sql_postgres"

  instance_name    = var.postgres_name_instance
  database_version = "POSTGRES_17"
  region           = var.region

  edition = "ENTERPRISE"

  tier              = "db-g1-small" # the machine type to use
  disk_size         = 10
  high_availability = false

  # labels for the instance
  project     = var.project
  environment = var.environment

  # IP configuration for the instance
  ipv4_enabled = true

}

# Cloud SQL PostgreSQL databases
resource "google_sql_database" "database_production" {
  name     = "fluid_droplet_shiphero_production"
  instance = module.postgres_db_instance.instance_name
}

resource "google_sql_database" "database_production_queue" {
  name     = "fluid_droplet_shiphero_production_queue"
  instance = module.postgres_db_instance.instance_name
}

resource "google_sql_database" "database_production_cache" {
  name     = "fluid_droplet_shiphero_production_cache"
  instance = module.postgres_db_instance.instance_name
}

resource "google_sql_database" "database_production_cable" {
  name     = "fluid_droplet_shiphero_production_cable"
  instance = module.postgres_db_instance.instance_name
}

resource "google_sql_user" "users" {
  name     = "shiphero_production_user"
  instance = module.postgres_db_instance.instance_name
  password = var.postgres_password_production_user
}