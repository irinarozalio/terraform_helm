# VPC variables for production
vpc_cidr = "10.0.0.0/16"
public_subnet_1_cidr = "10.0.1.0/24"
public_subnet_2_cidr = "10.0.2.0/24"
public_subnet_3_cidr = "10.0.5.0/24"
private_subnet_1_cidr = "10.0.3.0/24"
private_subnet_2_cidr = "10.0.4.0/24"
private_subnet_3_cidr = "10.0.6.0/24"
# remote state
remote_state_key = "PROD/infrastructure.tfstate"
remote_state_bucket = "ecs-fargate-terraform-remote-state-ira1"

ecs_domain_name = "irinarozalio.com"
ecs_cluster_name = "Production-ECS-Cluster"
eks_cluster_name = "Kubernetes"
internet_cidr_blocks = "0.0.0.0/0"
#ecs_service_name = "FARGATE"

# Helm chart
helm_home = "/home/ubuntu/terraform_projects/ecs_fargate/infra_helm/.helm"

# Application
ecs_service_name = "nginx"