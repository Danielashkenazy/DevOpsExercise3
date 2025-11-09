



provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project = "asterra-ex3"
      Owner   = "daniel"
    }
  }
}






module "network" {
  source = "./modules/network"
}

module "bastion_rds" {
  source = "./modules/bastion_rds"
  vpc_id = module.network.vpc_id
  private_subnets = module.network.private_subnets
  public_subnets = module.network.public_subnets
  db_name = var.db_name
  db_password = var.db_password
  db_username = var.db_username
  key_name = var.key_name
  key_path = var.key_path
  allowed_bastion_ip = var.allowed_bastion_ip
  instance_type = var.instance_type
  ecs_securityGroup_ID = module.s3_fargate_geojson.ecs_securityGroup_ID
}


module "s3_fargate_geojson" {
  source = "./modules/s3_fargate_geojson"
  vpc_id = module.network.vpc_id
  db_host = module.bastion_rds.db_endpoint
  db_username = var.db_username
  db_name= var.db_name
  db_password = var.db_password
  private_subnets = module.network.private_subnets
  region = var.region
}


module "Paas" {
  source = "./modules/PaaS"
  vpc_id = module.network.vpc_id
  private_subnet_id = module.network.private_subnets[0] 
  private_subnet_b_id = module.network.private_subnets[1]
  public_subnet_id = module.network.public_subnets
  key_name = var.key_name 
  instance_type = var.instance_type_wordpress_ecs
  WORDPRESS_DB_NAME = var.WORDPRESS_DB_NAME
  WORDPRESS_DB_USERNAME = var.WORDPRESS_DB_USERNAME
  WORDPRESS_DB_PASSWORD = var.WORDPRESS_DB_PASSWORD
}

module "microservice" {
  source = "./modules/microservice"
  aws_region = var.region
  vpc_id = module.network.vpc_id
  private_subnets = module.network.private_subnets
  vpc_cidr = module.network.vpc_cidr
  s3_bucket_name = module.s3_fargate_geojson.s3_bucket_name
}


#####Ecr Creation#####

