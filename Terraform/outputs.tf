##### OUTPUTS #####

# 🔹 רשתות
output "vpc_id" {
  value       = module.network.vpc_id
  description = "Main VPC ID "
}

output "private_subnets" {
  value       = module.network.private_subnets
  description = "Private subnets"
}

output "public_subnets" {
  value       = module.network.public_subnets
  description = "public subnets"
}

# 🔹 RDS ובסטיון
output "rds_endpoint" {
  value       = module.bastion_rds.db_endpoint
  description = "rds endpoint address"
}

output "bastion_public_ip" {
  value       = module.bastion_rds.bastion_public_ip
  description = "Bastion public Ip for ssh and debugging"
}

output "rds_connection_string" {
  value       = "postgresql://${var.db_username}:${var.db_password}@${module.bastion_rds.db_endpoint}:5432/${var.db_name}"
  sensitive   = true
  description = "Full rds connection through bastion credentials"
}


output "s3_bucket_name" {
  value       = module.s3_fargate_geojson.s3_bucket_name
  description = "S3 bucket name "
}

output "geojson_ecr_repository_url" {
  value       = module.s3_fargate_geojson.ecr_repo_url
  description = "ECR Repo for pushing containerized application"
}
output "geoprocessing_app_ecr_repository_url" {
  value       = module.microservice.ecr_repo_url
  description = "ECR Repo for pushing geo processing application"
}

output "ecs_cluster_name" {
  value       = module.s3_fargate_geojson.ecs_cluster_name
  description = "ECS cluster name "
}

output "ecs_task_definition_arn" {
  value       = module.s3_fargate_geojson.ecs_task_definition_arn
  description = "Fargate Task name"
}

output "eventbridge_rule_name" {
  value       = module.s3_fargate_geojson.event_rule_name
  description = "EventBridge rule name "
}
output "geo_processing_alb_name" {
  value       = module.microservice.microservice_alb_name
  description = "Geo Processing ALB name "
}