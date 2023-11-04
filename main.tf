# configure aws provider
provider "aws" {
    access_key = var.aws_access_key
    secret_key = var.aws_secret_key
    region = "us-east-1"
    #profile = "Admin"
}

#VPC
data "aws_vpc" "existing_vpc" {
  id = "vpc-027a19a734308c8ba"  # Replace with the ID of your existing VPC
}

# Creating Security Group to include ports 22, 8080, 8000 of ingress 
 resource "aws_security_group" "JenkinsSG" {
 name = "JenkinsD7_SG"
 vpc_id = data.aws_vpc.existing_vpc.id

 ingress {
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

 }

 ingress {
  from_port = 8080
  to_port = 8080
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  
 }

 ingress {
  from_port = 8000
  to_port = 8000
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  
 }

 egress {
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
 }
 
 tags = {
  "Name" : "JenkinsD7_SG"
  "Terraform" : "true"
 }

}


# Create Instance 1 (Jenkins)
resource "aws_instance" "Jenkins" {
  ami                    = "ami-053b0d53c279acc90"
  instance_type          = "t2.micro"
  key_name               = "Deployment6"
  subnet_id              = "subnet-0b01c2964708914d6"
  vpc_security_group_ids = [aws_security_group.JenkinsSG.id]
  user_data = "${file("jenkins.sh")}"
  
  
  tags = {
    "Name" : "Jenkins_D7_tf"
  }
}

# Create Instance 2 (AgentTerraform)
resource "aws_instance" "JAgent_terraform" {
  ami                    = "ami-053b0d53c279acc90"
  instance_type          = "t2.medium"
  key_name               = "Deployment6"
  subnet_id              = "subnet-0f3a361e89fffb6af"
  vpc_security_group_ids = [aws_security_group.JenkinsSG.id]
  user_data = "${file("terraform.sh")}"
  
  tags = {
    "Name" : "JAgent_Terraform_D7_tf"
  }
}

# Create Instance 3 (AgentDocker)
resource "aws_instance" "JAgent_docker" {
  ami                    = "ami-053b0d53c279acc90"
  instance_type          = "t2.medium"
  key_name               = "Deployment6"
  subnet_id              = "subnet-0f3a361e89fffb6af"
  vpc_security_group_ids = [aws_security_group.JenkinsSG.id]
  
  tags = {
    "Name" : "JAgent_Docker_D7_tf"
  }
}
