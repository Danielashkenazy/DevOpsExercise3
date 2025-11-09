####DB Variables###
variable "db_name" {
  description = "The DB name"
}
variable "db_username" {
  description = "db username. passed in root main.tf"
}
variable "db_password" {
  description = "db password. passed in root main.tf"
}

###Bastion Variables###
variable "allowed_bastion_ip" {
  description = "allowed ip for bastion connection. Passed from root varibales."
} 
variable "instance_type" {
  description = "instance type, passed from root variables"
}
variable "key_name" {
  description = "key name, passed from root variables"
}
variable "key_path" {
  description = "key path on the local user"
}



variable "vpc_id" {
  description = "VPC ID where RDS and Bastion will be deployed"
}

variable "private_subnets" {
  description = "List of private subnets for RDS subnet group"
  type        = list(string)
}

variable "public_subnets" {
  description = "List of public subnets for Bastion host"
}

variable "ecs_securityGroup_ID" {
  description = "ECS security group ID . For allowing access from the RDS and bastion"
}