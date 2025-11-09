output "db_endpoint" {
  description = "RDS endpoint for database connection"
  value       = aws_db_instance.postgis_rds.address
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.postgis_rds.db_name
}

output "db_username" {
  description = "Database username"
  value       = aws_db_instance.postgis_rds.username
}

output "bastion_public_ip" {
  description = "Public IP address of the bastion host"
  value       = aws_instance.bastion_host.public_ip
}

output "rds_security_group_id" {
  description = "Security Group ID of the RDS instance"
  value       = aws_security_group.rds_security_group.id
}