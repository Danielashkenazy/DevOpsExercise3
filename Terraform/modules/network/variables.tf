variable "private_subnet_a_AZ" {
    description = "Private_subnet_a_AZ"
    default = "us-west-1a"
}
variable "private_subnet_a_CIDR_Block" {
  description = "private subnet a CIDR block"
  default = "10.0.1.0/24"
}
variable "private_subnet_b_AZ" {
    description = "Private subnet b AZ"
    default = "us-west-1c"
}
variable "private_subnet_b_CIDR_Block" {
    description = "Private subnet B CIDR Block"
    default = "10.0.2.0/24"
}
variable "public_subnet_a_AZ" {
    description = "Public subnet AZ "
    default = "us-west-1a"
}
variable "public_subnet_CIDR_Block" {
  description = "Public subnet CIDR Block"
  default = "10.0.3.0/24"
}
variable "VPC_CIDR_Block" {
    description = "VPC CIDR Block"
    default = "10.0.0.0/16"
}   