####ECR creation for geo-processing app####

resource "aws_ecr_repository" "ecr_repo" {
    name = "geo-processing-app-repo"
    image_tag_mutability = "IMMUTABLE"
    image_scanning_configuration {
        scan_on_push = true
    }
    tags = {
        Name = "geo_processing_app_repo"
    }
}
####ECS Cluster and Task Definition for Geo-processing application####
resource "aws_ecs_cluster" "geo_processing_cluster" {
   name = "geo-processing-cluster"
    tags = {
         Name = "geo_processing_cluster"
    }
    setting {
      name = "containerInsights"
      value = "enabled"
    }
}

resource "aws_ecs_task_definition" "geo_processing_task" {
  family                   = "geo-processing-task"
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities  = ["FARGATE"]
  cpu                      = "256"
  memory                   = "2048"

  container_definitions = jsonencode([
    {
      name      = "geo-processing-container"
      image     = "${aws_ecr_repository.ecr_repo.repository_url}:latest"
      essential = true
      memory    = 512
      cpu       = 256
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
        logConfiguration = {
            logDriver = "awslogs"
            options = {
                "awslogs-group"         = "/ecs/geo-processing-logs"
                "awslogs-region"        = var.aws_region
                "awslogs-stream-prefix" = "ecs"
            }
        }
    }
  ])
  tags = {
        Name = "geo_processing_task_definition"
    }
}


####IAM Roles for ECS Task and Execution####
resource "aws_iam_role" "ecs_task_role" {
  name = "ecsTaskRole-geo-processing"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_allow_s3_access" {
  name = "ecsTaskAllowS3Access-geo-processing"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:HeadObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole-geo-processing"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  name       = "ecsTaskExecutionRolePolicyAttachment-geo-processing"
  roles      = [aws_iam_role.ecs_task_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

####Logging for Geo-processing Fargate Tasks####
resource "aws_cloudwatch_log_group" "geo_processing_log_group" {
  name              = "/ecs/geo-processing-logs"
  retention_in_days = 7
  tags = {
        Name = "geo_processing_log_group"
    }
}
####Security gorups and Load Balancer for Geo-processing application####
resource "aws_security_group" "geo_processing_lb_sg" {
  name = "geo-processing-sg"
  description = "Security group for geo processing load balancer"
    vpc_id = var.vpc_id
    tags = {
        Name = "geo_processing_lb"
    }
    ingress {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
    }
    egress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "ecs_task_sg" {
  name="geo-processing-ecs-task-sg"
  description = "Security group for geo processing ecs task"
    vpc_id = var.vpc_id
    tags = {
        Name = "geo_processing_ecs_task_sg"
    }
    ingress {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      security_groups = [aws_security_group.geo_processing_lb_sg.id]
    }
    egress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
}
####Load Balancer for Geo-processing application####
resource "aws_lb" "geo_processing_lb" {
  name               = "geo-processing-lb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.geo_processing_lb_sg.id]
  subnets            = var.private_subnets

  enable_deletion_protection = false

  tags = {
    Name = "geo_processing_lb"
  }
}

resource "aws_lb_target_group" "geo_processing_tg" {
  name = "geo-processing-tg"
  port = 8080
    protocol = "HTTP"
    vpc_id = var.vpc_id
    target_type = "ip"
    health_check {
      path                = "/health"
      protocol            = "HTTP"
      matcher             = "200-399"
      interval            = 30
      timeout             = 5
      healthy_threshold   = 2
      unhealthy_threshold = 2
    }
}
resource "aws_lb_listener" "geo_processing_listener" {
  load_balancer_arn = aws_lb.geo_processing_lb.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.geo_processing_tg.arn
  }
}
####ECS Service for Geo-processing application####
resource "aws_ecs_service" "geo_processing_service" {
  name            = "geo-processing-service"
  cluster         = aws_ecs_cluster.geo_processing_cluster.id
  task_definition = aws_ecs_task_definition.geo_processing_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [var.private_subnets[0]]
    security_groups = [aws_security_group.ecs_task_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.geo_processing_tg.arn
    container_name   = "geo-processing-container"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.geo_processing_listener]

  tags = {
        Name = "geo_processing_service"
    }
}
####Auto-scaling for Geo-processing ECS Service####
resource "aws_appautoscaling_target" "geo_processing_target" {
  max_capacity = 5
  min_capacity = 1
  resource_id  = "service/${aws_ecs_cluster.geo_processing_cluster.name}/${aws_ecs_service.geo_processing_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace = "ecs"

}

resource "aws_appautoscaling_policy" "geo_processing_policy_cpu" {
    name = "geo-processing-autoscaling-policy"
    policy_type = "TargetTrackingScaling"
    resource_id = aws_appautoscaling_target.geo_processing_target.resource_id
    scalable_dimension = aws_appautoscaling_target.geo_processing_target.scalable_dimension
    service_namespace = aws_appautoscaling_target.geo_processing_target.service_namespace
    
    target_tracking_scaling_policy_configuration {
        predefined_metric_specification {
        predefined_metric_type = "ECSServiceAverageCPUUtilization"
        }
        target_value = 60
        scale_in_cooldown = 60
        scale_out_cooldown = 60
    }
}

resource "aws_appautoscaling_policy" "geo_scaling_policy_memory" {
  name               = "geo-scaling-policy-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.geo_processing_target.resource_id
  scalable_dimension = aws_appautoscaling_target.geo_processing_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.geo_processing_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = 70
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}