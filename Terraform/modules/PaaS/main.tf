####Launch template for Autoscaling group####


resource "aws_launch_template" "paas_lt" {
    name_prefix = "ecs_LT-"
    image_id = data.aws_ami.ecs_ami.id
    instance_type = var.instance_type
    key_name = var.key_name
    
    iam_instance_profile {
      name = aws_iam_instance_profile.ecs_instance_profile.name
    }
    user_data =  base64encode(<<-EOF
              #!/bin/bash
              echo "ECS_CLUSTER=${aws_ecs_cluster.main.name}" >> /etc/ecs/ecs.config
              EOF
  )
    network_interfaces {
      associate_public_ip_address = false
      security_groups = [aws_security_group.ecs_sg.id]
    }   
      tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ECS-Instance"
    }
}
}
####Iam roles and networking permissions for ECS Instances####

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}


resource "aws_security_group" "ecs_sg" {
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ECS-SG"
  }
}

resource "aws_security_group" "alb_sg" {
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "ALB-SG"
  }
}
data "aws_ami" "ecs_ami" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}


resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy_attachment" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}



####Auto scaling group####
resource "aws_autoscaling_group" "paas_asg" {
  launch_template {
    id      = aws_launch_template.paas_lt.id
    version = "$Latest"
  }

  min_size                  = 2
  max_size                  = 3
  desired_capacity          = 2
  vpc_zone_identifier      = [var.private_subnet_id]
  health_check_type         = "EC2"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "ECS-ASG-Instance"
    propagate_at_launch = true
  }
}


####Load balancer Confifuration####

resource "aws_lb" "ecs_lb" {
  name ="ecs-lb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb_sg.id]
  subnets = [var.public_subnet_id,var.private_subnet_b_id]
  tags = {
    Name = "ECS-LB"
  }  
}
resource "aws_lb_target_group" "ecs_tg" {
  name     = "ecs-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type  = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "ECS-TG"
  }
}

resource "aws_lb_listener" "ecs_listener" {
  load_balancer_arn = aws_lb.ecs_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg.arn
  }
}

####ECS Cluster and Service####
resource "aws_ecs_cluster" "main" {
  name = "ecs-cluster"

}

resource "aws_ecs_service" "wordpress_service" {
  name            = "wordpress-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.wordpress_task.arn
  desired_count   = 2
  launch_type     = "EC2"

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg.arn
    container_name   = "wordpress"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.ecs_listener]
  
}
#####RDS Instance#####
resource "aws_db_subnet_group" "rds_subnets" {
  name = "rds-subnet-group"
  subnet_ids = [var.private_subnet_id,var.private_subnet_b_id]
  tags = {
    Name = "RDS Subnet Group"
  }
}
resource "aws_security_group" "rds_sg" {
  name = "rds-sg"
  vpc_id = var.vpc_id
  ingress {
    description = "Allow MySQL traffic from ECS SG"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name ="RDS-SG"
  }
}

resource "aws_db_instance" "wordpress_db" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  db_name              = var.WORDPRESS_DB_NAME
  username             = var.WORDPRESS_DB_USERNAME
  password             = var.WORDPRESS_DB_PASSWORD
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnets.name
  publicly_accessible = false
  deletion_protection = false
  backup_retention_period = 1
  tags = {
    Name = "WordPress-RDS"
  }
}

resource "aws_ecs_task_definition" "wordpress_task" {
  family                   = "wordpress-task"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "wordpress"
      image     = "wordpress:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      environment = [
        {
          name  = "WORDPRESS_DB_HOST"
          value = aws_db_instance.wordpress_db.address
        },
        {
          name  = "WORDPRESS_DB_USER"
          value = var.WORDPRESS_DB_USERNAME
        },
        {
          name  = "WORDPRESS_DB_PASSWORD"
          value = var.WORDPRESS_DB_PASSWORD
        },
        {
          name  = "WORDPRESS_DB_NAME"
          value = var.WORDPRESS_DB_NAME
        }
      ]
    }
  ])
}


  