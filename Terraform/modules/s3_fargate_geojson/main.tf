####Random number generation for uniqe bucket naming####
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

####S3 Bucket to store GeoJSON files####
resource "aws_s3_bucket" "geoJsonBucket" {
    bucket = "geojsonbucket-${random_id.bucket_suffix.hex}"
    force_destroy = true
    tags = {
        Name = "geoJsonBucket"
        Environment = "Dev"
    }
}
resource "aws_s3_bucket_public_access_block" "geoJsonBucket_public_access_Block" {
    bucket = aws_s3_bucket.geoJsonBucket.id

    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true 
  
}

resource "aws_s3_bucket_notification" "getjson_events" {
  bucket = aws_s3_bucket.geoJsonBucket.id
  eventbridge = true
}
####Eventbridge trigger and configuration####
resource "aws_cloudwatch_event_rule" "s3_put_geojson" {
  name        = "s3-put-geojson"
  description = "Trigger ECS task when a .geojson is uploaded"
  event_pattern = jsonencode({
    "source": ["aws.s3"],
    "detail-type": ["Object Created"],
    "detail": {
      "bucket": { "name": [aws_s3_bucket.geoJsonBucket.bucket] },
      "object": { "key": [{ "suffix": ".geojson" }] }
    }
  })
  depends_on = [ aws_s3_bucket_notification.getjson_events ]
}


resource "aws_cloudwatch_event_target" "s3_to_ecs" {
    rule = aws_cloudwatch_event_rule.s3_put_geojson.name
    target_id = "s3-to-ecs-target"
    arn = aws_ecs_cluster.geojson_cluster.arn
    role_arn = aws_iam_role.events_invoke_ecs.arn
    ecs_target {
        launch_type = "FARGATE"
        task_count = 1
        task_definition_arn = aws_ecs_task_definition.geojson_task.arn
        network_configuration {
            subnets = [var.private_subnets[0]]
            security_groups = [ aws_security_group.ecs_tasks_sg.id ]
            assign_public_ip = true
            }
    }
    input_transformer {
      input_paths ={
        bucket ="$.detail.bucket.name"
        key = "$.detail.object.key"
      }
      input_template = <<EOF
      {
        "containerOverrides": [{
          "name": "geojson-app",
          "environment": [
            { "name": "S3_BUCKET", "value": "<bucket>" },
            { "name": "S3_KEY", "value": "<key>" }
          ]
        }] 
      }
      EOF
    }
    depends_on = [ aws_ecs_cluster.geojson_cluster, aws_ecs_task_definition.geojson_task , aws_iam_role.events_invoke_ecs,aws_iam_role_policy.events_invoke_ecs_policy]
}

####ECS Cluster and Task Definition for GeoJSON validation####
resource "aws_ecs_cluster" "geojson_cluster" {
    name = "geojson-cluster"
    tags = {
        Name = "geojson_ecs_cluster"
    }
}


resource "aws_ecs_task_definition" "geojson_task" {
    family = "geojson-processor"
    requires_compatibilities = ["FARGATE"]
    network_mode = "awsvpc"
    cpu = "256"
    memory = "512"
    execution_role_arn = aws_iam_role.ecs_execution_role.arn
    task_role_arn = aws_iam_role.fargate_task_role.arn
    container_definitions = jsonencode([
        {
           name      = "geojson-app",
      image     = "${aws_ecr_repository.geojson_repository.repository_url}:latest",
      essential = true,
      environment = [
        { name = "DB_HOST", value =  var.db_host},
        { name = "DB_NAME", value = var.db_name },
        { name = "DB_USER", value = var.db_username },
        { name = "DB_PASS", value = var.db_password },
        { name = "TABLE_NAME", value = "geo_features" },
        { name = "GEOM_SRID", value = "4326" }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.fargate_logs.name,
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_security_group" "ecs_tasks_sg" {
    name="ecs-tasks-sg"
    vpc_id = var.vpc_id
    description = "Allow outbound access from ECS tasks"
    egress  {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = [ "0.0.0.0/0"]
    }
    tags = {
        Name = "ecs_tasks_sg"
    }
}
####Iam Roles for ECS Task Execution and Fargate Task####
resource "aws_iam_role" "ecs_execution_role" {
    name = "ecs_execution_role"
    assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Principal" = { "Service": "ecs-tasks.amazonaws.com"},
        "Action": "sts:AssumeRole"
        }]
    })
    tags = {
        Name = "ecs_execution_role"
    }
}

resource "aws_iam_role_policy_attachment" "ecs_exec_attach" {
    role = aws_iam_role.ecs_execution_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "fargate_task_role" {
    name = "fargate_task_role"
    assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Principal" = { "Service": "ecs-tasks.amazonaws.com"},
        "Action": "sts:AssumeRole"
        }]
    })
    tags = {
        Name = "fargate_task_role"
    }
}

resource "aws_iam_role_policy" "fargate_s3_policy" {
    name = "fargate_s3_policy"
    role = aws_iam_role.fargate_task_role.id
    policy = jsonencode({
        Version: "2012-10-17",
        Statement:[{
        Effect: "Allow",
        Action: [
            "s3:GetObject",
            "s3:PutObject",
            "s3:ListBucket"
        ],
        Resource = [
            aws_s3_bucket.geoJsonBucket.arn,
            "${aws_s3_bucket.geoJsonBucket.arn}/*"
        ]
        }]
    })
}
resource "aws_iam_role" "events_invoke_ecs" {
    name ="events_invoke_ecs_role"
    assume_role_policy = jsonencode({
        Version: "2012-10-17",
        Statement: [{
            Effect: "Allow",
            Principal: {
                Service: "events.amazonaws.com"
            },
            Action: "sts:AssumeRole"
        }]
    })
}
resource "aws_iam_role_policy" "events_invoke_ecs_policy" {
  name = "events_invoke_ecs_policy"
  role = aws_iam_role.events_invoke_ecs.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = ["ecs:RunTask"]
        Resource = aws_ecs_task_definition.geojson_task.arn
        Condition = {
          ArnLike = { "ecs:cluster" = aws_ecs_cluster.geojson_cluster.arn }
        }
      },
      {
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          aws_iam_role.ecs_execution_role.arn,
          aws_iam_role.fargate_task_role.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs"
        ]
        Resource = "*"
      }
    ]
  })
  depends_on = [
  aws_ecs_cluster.geojson_cluster,
  aws_ecs_task_definition.geojson_task,
  aws_iam_role.events_invoke_ecs,
  aws_iam_role_policy.events_invoke_ecs_policy,
  aws_security_group.ecs_tasks_sg
]

}


####Logging for Fargate Tasks####
resource "aws_cloudwatch_log_group" "fargate_logs" {
  name              = "/ecs/geojson-app"
  retention_in_days = 7
}


####ECR Repository for GeoJSON validation application####
resource "aws_ecr_repository" "geojson_repository" {
    name = "geojson-repository"
    image_tag_mutability = "IMMUTABLE"
    image_scanning_configuration {
        scan_on_push = true
    }
    tags = {
        Name = "geojson_repository"
    }

}
