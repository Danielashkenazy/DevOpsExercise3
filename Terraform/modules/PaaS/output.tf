output "alb_dns_name" {
  description = "Public DNS of the ALB"
  value       = aws_lb.ecs_lb.dns_name
}

output "rds_endpoint" {
  description = "RDS MySQL Endpoint"
  value       = aws_db_instance.wordpress_db.address
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.wordpress_task.arn
}

