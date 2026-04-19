variable "region" {
  description = "AWS region to deploy the EKS cluster"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-demo"
}

variable "ecr_uri" {
  description = "Amazon ECR URI for the demo app image"
  type        = string
  # Example: 123456789012.dkr.ecr.us-east-1.amazonaws.com/demo-app
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "Public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "Private subnet CIDRs"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "t3.small"
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "node_desired_size" {
  description = "Desired number of worker nodes at launch"
  type        = number
  default     = 1
}

variable "hpa_min_replicas" {
  description = "Minimum pod replicas for HPA"
  type        = number
  default     = 1
}

variable "hpa_max_replicas" {
  description = "Maximum pod replicas for HPA"
  type        = number
  default     = 10
}

variable "hpa_cpu_threshold" {
  description = "CPU utilization percentage that triggers HPA scale-up"
  type        = number
  default     = 50
}

variable "max_sessions" {
  description = "Max concurrent user sessions before app reports overloaded"
  type        = number
  default     = 3
}

variable "tags" {
  description = "Common tags applied to all AWS resources"
  type        = map(string)
  default     = {
    Project     = "eks-demo"
    Environment = "demo"
    ManagedBy   = "terraform"
  }
}