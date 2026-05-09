variable "aws_region" {
     default = "ap-south-2" 
     description = "AWS region to deploy the resources"
     }

variable "vpc_cidr" {
    default = "10.0.0.0/16" 
    description = "CIDR block for the VPC"
    }

variable "public_subnet_1_cidr" {
    default = "10.0.1.0/24"
    description = "CIDR block for the first public subnet"
}

variable "public_subnet_2_cidr" {
    default = "10.0.2.0/24"
    description = "CIDR block for the second public subnet"
}
