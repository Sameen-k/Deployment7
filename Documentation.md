1. The first terraform main.tf file is utilized to create the Jenkins infrastructure which includes 3 EC2 instances. There is a user-data script on that first main.tf file that installs Jenkins on the first instance and a second user-data script that installs terraform and some dependencies (see terraform.sh). When the third instance launched docker was installed manually and the following dependencies:
default-jre, software-properties-common, add-apt-repository -y ppa:deadsnakes/ppa, python3.7, python3.7-venv, build-essential, libmysqlclient-dev, python3.7-dev.

Some pre-existing resources were used to create this infrastructure. Refer to main.tf in the "Terraform Jenkins"  folder to see the usage of pre-existing VPC and subnets.



