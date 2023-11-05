#Purpose

#System Diagram

![Deployment 7 drawio](https://github.com/Sameen-k/Deployment7/assets/128739962/dd439f88-8cea-4685-bd48-efa9828a63eb)

# Steps
### Launching Jenkins Infrastructure with Terraform:
1. The first terraform main.tf file is utilized to create the Jenkins infrastructure which includes 3 EC2 instances. There is a user-data script on that first main.tf file that installs Jenkins on the first instance and a second user-data script that installs terraform and some dependencies (see terraform.sh). When the third instance launched docker was installed manually and the following dependencies:
   
``default-jre, software-properties-common, add-apt-repository -y ppa:deadsnakes/ppa, python3.7, python3.7-venv, build-essential, libmysqlclient-dev, python3.7-dev``
  
  Some pre-existing resources were used to create this infrastructure. Refer to main.tf in the "Terraform Jenkins"  folder to see the usage of pre-existing VPC and subnets.

2. After the infrastructure has been applied by Terraform, we can now configure the Jenkins agents on each of the two EC2s. This can be done by using the .pem file of the Key-pair that's being utilized, then copying it and saving it to Jenkins as secret text along with the IP address of the Agent instance. The Jenkins agent is configured through SSH. In this case, I utilized a pre-existing key pair for deployment 6.

3. This is a good time to configure your AWS credentials onto Jenkins. On the Jenkins interface, under the credentials tab, select "System" and "Global Credentials", and add your AWS credentials for both your access key and secret access key. The keys are saved in Jenkins and the Jenkins file with the names "AWS_ACCESS_KEYS" and "AWS_SECRET_KEYS". Jenkins file also has assigned the keys a variable that must match the terraform file. In this deployment, the keys are saved as variables called "aws_access_key" and "aws_secret_keys". The variables must stay consistent with both the Jenkins file and the main.tf file.

4. Lastly be sure to add the "Pipeline Keep Running" Jenkins plugin and the "Docker Pipeline" plugin.


### Init Terrraform - main.tf
In this instance, there are a few terraform files that are run in the "Init Terraform" folder. First is the main.tf file (this is not referring to the main.tf file from the Jenkins architecture).

```
  provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = "us-east-1"
}
```

This section configures the AWS provider for Terraform. It specifies the AWS access key, the secret key within variables, and the region where the resources will be deployed.

```
# Cluster
resource "aws_ecs_cluster" "aws-ecs-cluster" {
  name = "bankapp-cluster"
  tags = {
    Name = "bank-ecs"
  }
}
```

This section creates an ECS cluster named "bankapp-cluster" with the associated tag "Name" set to "bank-ecs". A cluster is a group of servers that provides resources for whatever you decide to host on that respective cluster. ECS Cluster is an environment for any container projects that are hosted.

```
resource "aws_cloudwatch_log_group" "log-group" {
  name = "/ecs/bank-logs"

  tags = {
    Application = "bank-app"
  }
}
```

This Terraform section is responsible for creating a CloudWatch Log Group in AWS, which will log and monitor AWS resources and applications. 

```
# Task Definition

resource "aws_ecs_task_definition" "aws-ecs-task" {
  family = "bank-task"

  container_definitions = <<EOF
  [
  {
      "name": "bank-container",
      "image": "sameenk/bankapp7:latest",
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/bank-logs",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "portMappings": [
        {
          "containerPort": 8000
        }
      ]
    }
  ]
  EOF
```

This section of the terraform file defines the container configuration for the task. It specifies the container name, the Docker image to use, the logging configuration for the container, and the port mapping for the container (8000). This block has an additional section below:

```

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = "1024"
  cpu                      = "512"
  execution_role_arn       = "arn:aws:iam::380330819214:role/ecsTaskExecutionRole"
  task_role_arn            = "arn:aws:iam::380330819214:role/ecsTaskExecutionRole"

}
```

This portion specifies that the task definition discussed previously is compatible with the Fargate, which means that the containers defined in this task is being run on Fargate. The memory and CPU settings specify the amount of memory and CPU units to be allocated to the task when it is running. The "execution_role_arn" and "task_role_arn" are the IAM roles used for the task's execution and task permissions. They define the AWS roles that provide the necessary permissions to run the task and access other AWS resources. 

```
# ECS Service
resource "aws_ecs_service" "aws-ecs-service" {
  name                 = "bank-ecs-service"
  cluster              = aws_ecs_cluster.aws-ecs-cluster.id
  task_definition      = aws_ecs_task_definition.aws-ecs-task.arn
  launch_type          = "FARGATE"
  scheduling_strategy  = "REPLICA"
  desired_count        = 2
  force_new_deployment = true

  network_configuration {
    subnets = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]
    assign_public_ip = false
    security_groups  = [aws_security_group.ingress_app.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.bank-app.arn
    container_name   = "bank-container"
    container_port   = 8000
  }

}
```

This section configures the ECS service with details such as the service name, cluster, task definition, launch type, scheduling strategy, desired count, network configuration, and load balancer configuration. 

A major point to note is the scheduling strategy that specifies the scheduling strategy for the service, which, in this case, is set to "REPLICA" to maintain a specified number of instances of the task. In this case, the desired count is set to 2. This means that even if one instance of the task is shut down, a new one will be created in its place. In this block, the ECS service is told where to host these tasks (within private subnets a and b).

The load balancer is also associated with the application containers. 

#### Init Terrraform - ALB.tf
There is another terraform file that is used to configure the application load balancer. 

```
#Target Group
resource "aws_lb_target_group" "bank-app" {
  name        = "bank-app"
  port        = 8000
  protocol    = "HTTP"
  target_type = "IP"
  vpc_id      = aws_vpc.app_vpc.id

  health_check {
    enabled = true
    path    = "/health"
  }

  depends_on = [aws_alb.bank_app]
}
```

This block defines the AWS Application Load Balancer target group. It specifies the target group's name, port, protocol, target type, VPC ID, and health check settings. It depends on the existence of an ALB named "bank_app". The target groups are being set to the containers 

```
#Application Load Balancer
resource "aws_alb" "bank_app" {
  name               = "bank-lb"
  internal           = false
  load_balancer_type = "application"

  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id,
  ]

  security_groups = [
    aws_security_group.http.id,
  ]

  depends_on = [aws_internet_gateway.igw]
}
```

This section configures an Application Load Balancer (ALB) on AWS. It sets the ALB's name, internal visibility, load balancer type, subnets, and security groups. It depends on the existence of an internet gateway named "igw".

```
resource "aws_alb_listener" "bank_app_listener" {
  load_balancer_arn = aws_alb.bank_app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.bank-app.arn
  }
}

output "alb_url" {
  value = "http://${aws_alb.bank_app.dns_name}"
}
```

this portion of the file defines the configuration for accepting incoming traffic on a specific port (80) and protocol (HTTP). It is responsible for "forwarding" this traffic to the designated target group. This output block defines an output variable called "alb_url" that provides the URL for the ALB created in the script. This URL is created along with the creation of the application load balancer, and this is how the application is accessed.

### Init Terrraform - VPC.tf
This file is straightforward, it's configuring a VPC, two public subnets, and two private subnets in each availability zone (US-east1a and US-east1b). There are 2 route tables, 1 private and 1 public. An internet gateway was configured as well as a NAT Gateway. Please refer to the VPC.tf in the "Init Terraform" folder to see more details. 

### Docker File: 

```
FROM python:3.7

RUN git clone https://github.com/Sameen-k/Deployment7.git

WORKDIR Deployment7

RUN pip install pip --upgrade

RUN pip install -r requirements.txt

RUN pip install mysqlclient

RUN pip install gunicorn

EXPOSE 8000

ENTRYPOINT python -m gunicorn app:app -b 0.0.0.0
```

This is the docker file that was run to create the image for the container that will be created. In this docker file, the GitHub repo was cloned, dependencies were installed, the port was set for the application, and the application was launched. This docker file will be run, and the image that's created as a result will be pushed to Docker Hub and then later be pulled from Docker Hub to be used to create a container.

### Jenkins Pipeline:

![Screen Shot 2023-11-04 at 6 08 50 PM](https://github.com/Sameen-k/Deployment7/assets/128739962/3fbdf6df-e9aa-4b44-98c1-87c3d553ed72)

This is an image of the Jenkins pipeline being successfully run. The test, build, login, and push are all carried out in Jenkins Agent2 (docker installed). The last few stages involve Jenkins Agent1 (terraform) to run the terraform files in the "Init Terraform" folder through the Init, plan, and apply stages. There is also a destroy stage that has been commented out that destroys all the main infrastructure 
