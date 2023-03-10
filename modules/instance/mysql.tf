# Default provider
provider "google" {
  region  = var.default_region
  zone    = var.default_zone
  project = var.project_name
}

# MySQL instance creation
resource "google_sql_database_instance" "mysql_instance" {
  provider            = google
  name                = var.instance_name
  region              = var.default_region
  database_version    = var.database_version
  deletion_protection = var.instance_deletion_protection_enabled

  connection {
    port = var.instance_connection_port
  }

  settings {
    tier              = var.instance_type
    disk_type         = var.instance_disk_type
    disk_size         = var.instance_disk_size
    disk_autoresize   = var.instance_disk_autoresize
    availability_type = var.instance_availability_type

    backup_configuration {
      enabled            = var.database_backup_enabled
      start_time         = var.database_backup_start_time
      binary_log_enabled = var.database_backup_binary_log_enabled
    }

    ip_configuration {
      ipv4_enabled    = var.instance_public_ip_enabled
      private_network = var.instance_private_ip_enabled ? "projects/${var.project_name}/global/networks/${var.vpc_id}" : null
    }
  }
}

# MySQL databases creation
module "mysql_databases" {
  count               = length(var.databases_names)
  source              = "../database"
  instance_name       = google_sql_database_instance.mysql_instance.name
  database_collation  = var.database_collation
  database_name       = var.databases_names[count.index]
}

# MySQL instance user creation
module "mysql_instance_user" {
  source            = "../user"
  project_name      = var.project_name
  instance_name     = google_sql_database_instance.mysql_instance.name
  instance_username = var.instance_username
}

# MySQL job to start instance creation
module "mysql_instance_start_scheduler_job" {
  source                = "../scheduler"
  project_name          = var.project_name
  service_account       = var.service_account
  default_region        = var.default_region
  default_zone          = var.default_zone
  instance_name         = google_sql_database_instance.mysql_instance.name
  job_name              = "${google_sql_database_instance.mysql_instance.name}-start-job"
  job_description       = "Job to start MySQL instance"
  job_activation_policy = "ALWAYS"
  job_start_cron        = var.instance_job_start_event_cron
  job_time_zone         = var.instance_job_time_zone
  job_attempt_deadline  = var.instance_job_attempt_deadline
  job_paused            = var.instance_job_start_event_paused
}

# MySQL job to stop instance creation
module "mysql_instance_stop_scheduler_job" {
  source                = "../scheduler"
  project_name          = var.project_name
  service_account       = var.service_account
  default_region        = var.default_region
  default_zone          = var.default_zone
  instance_name         = google_sql_database_instance.mysql_instance.name
  job_name              = "${google_sql_database_instance.mysql_instance.name}-stop-job"
  job_description       = "Job to stop MySQL instance"
  job_activation_policy = "NEVER"
  job_start_cron        = var.instance_job_stop_event_cron
  job_time_zone         = var.instance_job_time_zone
  job_attempt_deadline  = var.instance_job_attempt_deadline
  job_paused            = var.instance_job_stop_event_paused
}

# MySQL instance host secret creation
module "mysql_instance_host_secret" {
  source        = "../secret"
  project_name  = var.project_name
  secret_name   = "${var.instance_name}-db-host"
  secret_value  = google_sql_database_instance.mysql_instance.ip_address.0.ip_address
}

# MySQL instance socket secret creation
module "mysql_instance_socket_secret" {
  source        = "../secret"
  project_name  = var.project_name
  secret_name   = "${var.instance_name}-db-socket"
  secret_value  = "/cloudsql/${var.project_name}:${var.default_region}:${google_sql_database_instance.mysql_instance.name}"
}
