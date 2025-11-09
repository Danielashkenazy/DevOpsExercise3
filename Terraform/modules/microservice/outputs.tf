output "ecr_repo_url" {
  value = aws_ecr_repository.ecr_repo.repository_url
}
output "microservice_alb_name" {
  value = aws_lb.geo_processing_lb.dns_name
}