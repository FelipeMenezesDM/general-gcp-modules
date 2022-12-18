# Default provider
provider "google" {
  region  = var.default_region
  zone    = var.default_zone
  project = var.project_name
}

# User random password
resource "random_password" "sql_user_password" {
  length           = 12
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# SQL user creation
resource "google_sql_user" "sql_user_username" {
  provider = google
  name     = var.instance_username
  instance = var.instance_name
  password = random_password.sql_user_password.result
}

# SQL user username secret creation
module "user_username_secret" {
  source          = "../secret"
  project_name    = var.project_name
  default_region  = var.default_region
  default_zone    = var.default_zone
  secret_name     = "${var.instance_name}-db-username"
  secret_value    = google_sql_user.sql_user_username.name
}

# SQL user password secret creation
module "user_password_secret" {
  source          = "../secret"
  project_name    = var.project_name
  default_region  = var.default_region
  default_zone    = var.default_zone
  secret_name     = "${var.instance_name}-db-password"
  secret_value    = random_password.sql_user_password.result
}