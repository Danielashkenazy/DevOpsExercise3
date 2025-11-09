
####RDS configuration + PostGIS installation via Bastion Host####
resource "aws_db_parameter_group" "postgres_params" {
    name = "postgres-with-postgis"
    family = "postgres15"
    description = "Paramaeter group for PostGIS"
    tags = {
        Name = "postgres_params"
    }
}

resource "aws_db_subnet_group" "rds_Subnet" {
    name = "rds_subnet_group"
    subnet_ids = var.private_subnets
    tags = {
      Name ="rds-subnet-group"
    }
}
resource "aws_db_instance" "postgis_rds" {
    identifier = "postgis-rds"
    engine = "postgres"
    engine_version = "15.12"
    db_name = var.db_name
    instance_class = "db.t3.micro"
    allocated_storage = 20
    username = var.db_username
    password = var.db_password
    parameter_group_name = aws_db_parameter_group.postgres_params.name
    db_subnet_group_name = aws_db_subnet_group.rds_Subnet.name
    vpc_security_group_ids = [ aws_security_group.rds_security_group.id ]
    publicly_accessible = false
    multi_az = false
    storage_type = "gp2"
    skip_final_snapshot = true
    storage_encrypted = true

    tags = {
        Name = "postgis_rds_instance"
    }
    depends_on = [ aws_db_subnet_group.rds_Subnet, aws_db_parameter_group.postgres_params ,aws_security_group.rds_security_group]
}

resource "aws_security_group" "rds_security_group" {
  name="rds_sg"
    description = "Allow Postgres access"
    vpc_id = var.vpc_id
    ingress  {
        from_port   = 5432
        to_port     = 5432
        protocol    = "tcp"
        security_groups =[aws_security_group.bastion_sg.id,var.ecs_securityGroup_ID]
    }
    ingress  {
        from_port   = 5432
        to_port     = 5432
        protocol    = "tcp"
        security_groups =[var.ecs_securityGroup_ID]
    }
    egress  {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = [ "0.0.0.0/0"]
    }
    tags = {
        Name = "rds_security_group"
    }
}

#####End of RDS Resource#####


####PostGIS installation and external access to the RDS instance for management purposes####

data "aws_ami" "ubuntu" {
  most_recent = true
  owners = ["099720109477"] # Canonical
    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
    }
}

resource "aws_security_group" "bastion_sg" {
  name = "bastion_sg"
    description = "Allow SSH access to bastion host"
    vpc_id = var.vpc_id
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = [var.allowed_bastion_ip]
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = [ "0.0.0.0/0"]
    }
    tags = {
        Name = "bastion_sg"
    }
}   
resource "aws_instance" "bastion_host" {
    ami           = data.aws_ami.ubuntu.id
    instance_type = var.instance_type
    subnet_id     = var.public_subnets
    vpc_security_group_ids = [ aws_security_group.bastion_sg.id ]
    key_name = var.key_name # Replace with your actual key pair name
    associate_public_ip_address = true
    tags = {
        Name = "bastion_host"
    }
    depends_on = [ aws_security_group.bastion_sg ]
}
####The null_resource to install PostGIS on the RDS instance via the Bastion Host, imporovised user data script for RDS####
resource "null_resource" "enable_postgis" {
    depends_on = [ aws_instance.bastion_host,aws_db_instance.postgis_rds ]
    connection {
      type = "ssh"
      user = "ubuntu"
      host = aws_instance.bastion_host.public_ip
      private_key = file(var.key_path)
    }
    provisioner "remote-exec" {
      inline = [
        "sudo apt-get update -y",
        "sudo apt-get install postgresql-contrib postgresql-client -y",
        "PGPASSWORD='${var.db_password}' psql -h ${aws_db_instance.postgis_rds.address} -U ${var.db_username} -d ${var.db_name} -c \"CREATE EXTENSION IF NOT EXISTS postgis;\""
      ]
    }
}