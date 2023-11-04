The first terraform main.tf file is utilized to create the Jenkins infrastructure which includes 3 EC2 instances. There is a user-data script on that first main.tf file that installs Jenkins on the first instance and a second user data script that installs terraform as well as some dependencies (see terraform.sh). When the third instance launched docker was installed manually. Some pre-existing resources were used to create this infrastructure. Refer to main.tf in the Jenkins Infrastructure folder to see the usage of pre-existing VPC and subnets.



