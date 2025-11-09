variable "aws_region" {
  description = "aws region"
}
variable "private_subnets" {
  description = "private subnets"
  type = list(string)
}
variable "vpc_id" {
  description = "value for vpc id"
}
variable "vpc_cidr" {
  description = "vpc cidr"
}
variable "s3_bucket_name" {
  description = "s3_bucket_name"
}