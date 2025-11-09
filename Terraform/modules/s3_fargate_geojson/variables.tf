
variable "vpc_id" {
  description = "VPC ID input from network module "
}
variable "private_subnets" {
  description = "Main private subnet"
  
}
variable "region" {
  description = "region"
}

variable "db_host" {
  description = "Endpoint of the POSTGIS RDS DB"
}
variable "db_username" {
  description = "Database master username"
 
}

variable "db_password" {
  description = "Database master password" 
  sensitive   = true
}

variable "db_name" {
  description = "Database name"
}