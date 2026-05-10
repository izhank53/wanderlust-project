#creating AWS VPS 

resource "aws_vpc" "main_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "wanderlust-vpc"
  }
}


#creating public subnets

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "wanderlust_public_subnet_1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags = {
    Name = "wanderlust_public_subnet_2"
  }
}


#creating internet gateway

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "wanderlust-igw"
  }
}


#creating route table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "wanderlust-public-rt"
  }
}



#associating route table with public subnets

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

#creating security group 

resource "aws_security_group" "main_sg" {
  name        = "wanderlust-sg"
  description = "Security group for Wanderlust application"
  vpc_id      = aws_vpc.main_vpc.id

  #ingress is browser to server (incoming) and 
  # egress is server to browser (outgoing) traffic

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  #/
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 27017
    to_port     = 27017
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
    Name = "wanderlust-sg"
  }
}


#Eks cluster IAM role and policy

resource "aws_iam_role" "eks_cluster_role" {
  name = "wanderlust-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# EKS Worker Node IAM Role

resource "aws_iam_role" "eks_node_group_role" {

  name = "wanderlust-eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Worker Node Policy

resource "aws_iam_role_policy_attachment" "worker_node_policy" {

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"

  role = aws_iam_role.eks_node_group_role.name
}

# CNI Policy

resource "aws_iam_role_policy_attachment" "cni_policy" {

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"

  role = aws_iam_role.eks_node_group_role.name
}

# ECR Read Only Policy

resource "aws_iam_role_policy_attachment" "ecr_policy" {

  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"

  role = aws_iam_role.eks_node_group_role.name
}

#Attaching AmazonEKSClusterPolicy to the EKS cluster role

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"

  role = aws_iam_role.eks_cluster_role.name
}

#Creating EKS cluster

resource "aws_eks_cluster" "wanderlust_eks" {

  name     = "wanderlust-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  version = "1.31"

  vpc_config {
    subnet_ids = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]

  tags = {
    Name = "wanderlust-eks-cluster"
  }
}

resource "aws_eks_node_group" "wanderlust_node_group" {
  cluster_name    = aws_eks_cluster.wanderlust_eks.name
  node_group_name = "wanderlust-node-group"

  node_role_arn = aws_iam_role.eks_node_group_role.arn

  subnet_ids = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  scaling_config {

    desired_size = 1
    min_size     = 1
    max_size     = 2
  }

  instance_types = ["t3.medium"]

  

  capacity_type = "ON_DEMAND"
  ami_type      = "AL2_x86_64"

  disk_size = 20

  depends_on = [
    aws_iam_role_policy_attachment.worker_node_policy,
    aws_iam_role_policy_attachment.cni_policy,
    aws_iam_role_policy_attachment.ecr_policy
  ]

  tags = {
    Name = "wanderlust-node-group"
  }
}
