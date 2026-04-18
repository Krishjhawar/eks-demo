# ─── Cluster Outputs ──────────────────────────────────────────────────────
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "cluster_version" {
  description = "Kubernetes version running on the cluster"
  value       = module.eks.cluster_version
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded cluster CA certificate"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

# ─── ECR Outputs ──────────────────────────────────────────────────────────
output "ecr_repository_url" {
  description = "ECR repository URL — use this in your Jenkinsfile and deployment.yaml"
  value       = aws_ecr_repository.demo_app.repository_url
}

output "ecr_repository_arn" {
  description = "ECR repository ARN"
  value       = aws_ecr_repository.demo_app.arn
}

# ─── VPC Outputs ──────────────────────────────────────────────────────────
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by EKS nodes"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Public subnet IDs used by load balancer"
  value       = module.vpc.public_subnets
}

# ─── Node Group Outputs ───────────────────────────────────────────────────
output "node_group_iam_role_name" {
  description = "IAM role name attached to EKS worker nodes"
  value       = module.eks.eks_managed_node_groups["demo_nodes"].iam_role_name
}

output "node_security_group_id" {
  description = "Security group ID for EKS worker nodes"
  value       = module.eks.node_security_group_id
}

# ─── Handy Commands Output ────────────────────────────────────────────────
output "configure_kubectl" {
  description = "Run this command to configure kubectl after terraform apply"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "docker_login_command" {
  description = "Run this to authenticate Docker with ECR"
  value       = "aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${aws_ecr_repository.demo_app.repository_url}"
}