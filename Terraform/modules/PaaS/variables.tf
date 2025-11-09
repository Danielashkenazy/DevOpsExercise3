variable "vpc_id" {
  description = "VPC id "
}
variable "private_subnet_id" {
  description = "private subnet id "
}
variable "private_subnet_b_id" {
  description = "private subnet b ID "
}
variable "public_subnet_id" {
  description = "public subnet id "
}
variable "key_name" {
  description = "key name"
}
variable "instance_type" {
  description = "EC2 instance type"
  default     = "t3.micro"
}


variable "WORDPRESS_DB_NAME" {
  description = "Wordpress database name"
}
variable "WORDPRESS_DB_USERNAME" {
  description = "Wordpress database user"
}
variable "WORDPRESS_DB_PASSWORD" {
  description = "Wordpress database password"
}


