terraform{
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 6.0"
    }
}
}

provider "aws" {
    region = "ap-south-1"
  
}
#networking components
resource "aws_vpc" "test_vpc"{
    cidr_block = "11.0.0.0/16"
    tags = {
      name="test_vpc"
    }
}
output "vpc_id" {
    value = aws_vpc.test_vpc.id
}

resource "aws_subnet" "test_subnet" {
    vpc_id            = aws_vpc.test_vpc.id
    cidr_block        = "11.0.3.0/24"
    availability_zone = "ap-south-1a"
    tags = {
      name="test_subnet"
    }
}
output "subnet_id" {
    value = aws_subnet.test_subnet.id
}

resource "aws_internet_gateway" "test_igw" {
    vpc_id = aws_vpc.test_vpc.id
    tags = {
      name="test_igw"
    }
}
resource "aws_route_table" "test_route_table" {
    vpc_id = aws_vpc.test_vpc.id
    tags = {
      name="test_route_table"
    }
}   

resource "aws_route" "default_route" {
    route_table_id         = aws_route_table.test_route_table.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id             = aws_internet_gateway.test_igw.id
}

resource "aws_route_table_association" "test_route_table_association" {
    subnet_id      = aws_subnet.test_subnet.id
    route_table_id = aws_route_table.test_route_table.id
}

resource "aws_security_group" "test_sg" {
    name        = "test_sg"
    description = "Allow all inbound traffic"
    vpc_id      = aws_vpc.test_vpc.id

}

resource "aws_vpc_security_group_ingress_rule" "allow_http"{

    security_group_id = aws_security_group.test_sg.id
    
    from_port        = 80
    to_port          = 80
    ip_protocol         = "tcp"
    cidr_ipv4 = aws_vpc.test_vpc.cidr_block
}
resource "aws_vpc_security_group_ingress_rule" "allow_ssh"{

    security_group_id = aws_security_group.test_sg.id
    
    from_port        = 22
    to_port          = 22
    ip_protocol         = "tcp"
    cidr_ipv4 = aws_vpc.test_vpc.cidr_block
}
resource "aws_vpc_security_group_egress_rule" "allow_all_outbound"{

    security_group_id = aws_security_group.test_sg.id
    
    from_port        = 0
    to_port          = 0
    ip_protocol         = "-1"
    cidr_ipv4 = aws_vpc.test_vpc.cidr_block
}

output "security_group_id" {
    value = aws_security_group.test_sg.id
}

#ecs components
resource "aws_ecs_cluster" "test_ecs_cluster" {
    name = "test_ecs_cluster"
}

output "ecs_cluster_id" {
    value = aws_ecs_cluster.test_ecs_cluster.id
}

resource "aws_ecs_task_definition" "test_task_definition" {
    family                   = "test_task_definition"
    network_mode             = "awsvpc"
    requires_compatibilities = ["FARGATE"]
    cpu                      = "1024"
    memory                   = "3072"
    
    execution_role_arn = var.execution_role_arn

    container_definitions = jsonencode([
    {
      name      = "my-app"
      image     = "${var.ecr_uri}:${var.image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "test_ecs_service" {
    name            = "test_ecs_service"
    cluster         = aws_ecs_cluster.test_ecs_cluster.id
    task_definition = aws_ecs_task_definition.test_task_definition.arn
    desired_count   = 1
    launch_type     = "FARGATE"

    network_configuration {
        subnets         = [aws_subnet.test_subnet.id]
        security_groups = [aws_security_group.test_sg.id]
        assign_public_ip = true
    }
    depends_on = [aws_ecs_cluster.test_ecs_cluster]
}
