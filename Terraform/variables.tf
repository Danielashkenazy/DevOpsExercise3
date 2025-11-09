####Variables####


variable "db_username" {
  description = "Database master username"
  default     = "postgresadmin"
}

variable "db_password" {
  description = "Database master password"
  default = "PostgresAdmin123!"
  sensitive   = true
}

variable "db_name" {
  description = "Database name"
  default     = "postgres"
}

variable "region" {
  description = "AWS region"
  default     = "us-west-1"
}

variable "instance_type" {
  description = "EC2 instance type for bastion"
  default     = "t2.micro"
}

variable "key_name" {
  description = "Key pair name for SSH access to bastion host"
  default = "danwest1"
}
variable "key_path" {
    description = "Path to the private key file for SSH access to bastion host"
    default     = "C:/Users/danie/Downloads/danwest1.pem"
}
variable "allowed_bastion_ip" {
    description = "The ip's that can connect to the bastion host"
    default     = "77.137.77.5/32"
}
variable "instance_type_wordpress_ecs" {
  default     = "t3.micro"
}
variable "WORDPRESS_DB_NAME" {
  description = "value for wordpress database name"
  default     = "wordpress"
}
variable "WORDPRESS_DB_USERNAME" {
  description = "value for wordpress database username"
  default     = "wordpress_user"
}
variable "WORDPRESS_DB_PASSWORD" {
  description = "value for wordpress database password"
  default     = "wordpress_password"
}