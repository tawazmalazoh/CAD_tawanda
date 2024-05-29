provider "aws" {
  region = "ca-central-1"
}

# Create VPC
resource "aws_vpc" "tawaz" {
  cidr_block           = "10.50.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "tawaz-vpc"
  }
}

# Create Subnets
resource "aws_subnet" "subnet1" {
  vpc_id            = aws_vpc.tawaz.id
  cidr_block        = "10.50.1.0/24"
  availability_zone = "ca-central-1a"
}

resource "aws_subnet" "subnet2" {
  vpc_id            = aws_vpc.tawaz.id
  cidr_block        = "10.50.2.0/24"
  availability_zone = "ca-central-1a"
}

resource "aws_subnet" "subnet3" {
  vpc_id            = aws_vpc.tawaz.id
  cidr_block        = "10.50.3.0/24"
  availability_zone = "ca-central-1b"
}

resource "aws_subnet" "subnet4" {
  vpc_id            = aws_vpc.tawaz.id
  cidr_block        = "10.50.4.0/24"
  availability_zone = "ca-central-1b"
}

# Create Internet Gateway
resource "aws_internet_gateway" "tawaz" {
  vpc_id = aws_vpc.tawaz.id

  tags = {
    Name = "tawaz-igw"
  }
}

# Create Route Table and Route
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.tawaz.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tawaz.id
  }

  tags = {
    Name = "tawaz-public-route-table"
  }
}

# Associate Subnets with Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet3.id
  route_table_id = aws_route_table.public.id
}

resource "aws_s3_bucket" "tawaz" {
  bucket = "tawaz-bucket-123456" # Ensure the bucket name is unique globally by adding a unique identifier
}

resource "aws_iam_role" "tawaz" {
  name = "tawaz-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })
}

resource "aws_iam_role_policy" "tawaz" {
  name = "tawaz-policy"
  role = aws_iam_role.tawaz.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.tawaz.arn,
          "${aws_s3_bucket.tawaz.arn}/*",
        ]
      },
    ]
  })
}

resource "aws_security_group" "tawaz" {
  vpc_id = aws_vpc.tawaz.id

  ingress {
    from_port   = 3306
    to_port     = 3306
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
    Name = "tawaz-sg"
  }
}

resource "aws_db_instance" "tawaz" {
  allocated_storage = 20
  engine            = "mysql"
  engine_version    = "8.0.35"
  instance_class    = "db.t3.micro"
  db_name           = "tawazdb"
  username          = "admin"
  password          = "password"



  vpc_security_group_ids = [aws_security_group.tawaz.id]
  db_subnet_group_name   = aws_db_subnet_group.tawaz.name
}

resource "aws_db_subnet_group" "tawaz" {
  name       = "tawaz-subnet-group"
  subnet_ids = [aws_subnet.subnet1.id, aws_subnet.subnet3.id]

  tags = {
    Name = "tawaz-db-subnet-group"
  }
}

resource "aws_kms_key" "tawaz" {
  description             = "tawaz key"
  deletion_window_in_days = 10
}

resource "aws_lb" "tawaz" {
  name               = "tawaz-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.tawaz.id]
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet3.id]

  enable_deletion_protection = false
}

resource "aws_autoscaling_group" "tawaz" {
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1
  vpc_zone_identifier = [aws_subnet.subnet1.id, aws_subnet.subnet3.id]

  launch_configuration = aws_launch_configuration.tawaz.id

  tag {
    key                 = "Name"
    value               = "tawaz-asg"
    propagate_at_launch = true
  }
}

resource "aws_launch_configuration" "tawaz" {
  name            = "tawaz-launch-configuration"
  image_id        = "ami-07152885003fe0145"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.tawaz.id]

  lifecycle {
    create_before_destroy = true
  }

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World!" > index.html
              nohup python -m SimpleHTTPServer 80 &
              EOF
}

resource "aws_glue_job" "tawaz" {
  name     = "tawaz-glue-job"
  role_arn = aws_iam_role.tawaz.arn

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://tawaz-bucket-123456/glue-scripts/tawaz.py" # Make sure the script exists at this location
  }
}

output "vpc_id" {
  value = aws_vpc.tawaz.id
}

output "s3_bucket_name" {
  value = aws_s3_bucket.tawaz.bucket
}

output "iam_role_name" {
  value = aws_iam_role.tawaz.name
}

output "security_group_id" {
  value = aws_security_group.tawaz.id
}

output "rds_instance_endpoint" {
  value = aws_db_instance.tawaz.endpoint
}

output "kms_key_id" {
  value = aws_kms_key.tawaz.key_id
}

output "lb_dns_name" {
  value = aws_lb.tawaz.dns_name
}

output "autoscaling_group_name" {
  value = aws_autoscaling_group.tawaz.name
}
