output "s3_bucket_name" {
  value = aws_s3_bucket.geoJsonBucket.bucket
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.geojson_cluster.name
}

output "ecs_task_definition_arn" {
  value = aws_ecs_task_definition.geojson_task.arn
}

output "event_rule_name" {
  value = aws_cloudwatch_event_rule.s3_put_geojson.name
}

output "ecs_securityGroup_ID"{
  value = aws_security_group.ecs_tasks_sg.id
}

output "ecr_repo_url" {
  value = aws_ecr_repository.geojson_repository.repository_url
}