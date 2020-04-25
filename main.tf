provider "aws" {
  region = "${var.region}"
}

terraform {
  backend "s3" {}
} 

resource "aws_vpc" "production-vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true

  tags {
    Name = "Production-VPC"
  }
}

resource "aws_subnet" "public-subnet-1" {
  cidr_block        = "${var.public_subnet_1_cidr}"
  vpc_id            = "${aws_vpc.production-vpc.id}"
  availability_zone = "us-east-1a"

  tags {
    Name = "Public-Subnet-1"
    "kubernetes.io/cluster/Kubernetes" = "shared"
  }
}

resource "aws_subnet" "public-subnet-2" {
  cidr_block        = "${var.public_subnet_2_cidr}"
  vpc_id            = "${aws_vpc.production-vpc.id}"
  availability_zone = "us-east-1b"

  tags {
    Name = "Public-Subnet-2"
    "kubernetes.io/cluster/Kubernetes" = "shared"
  }
}

resource "aws_subnet" "public-subnet-3" {
  cidr_block        = "${var.public_subnet_3_cidr}"
  vpc_id            = "${aws_vpc.production-vpc.id}"
  availability_zone = "us-east-1c"

  tags {
    Name = "Public-Subnet-3"
    "kubernetes.io/cluster/Kubernetes" = "shared"
  }
}

resource "aws_subnet" "private-subnet-1" {
  cidr_block        = "${var.private_subnet_1_cidr}"
  vpc_id            = "${aws_vpc.production-vpc.id}"
  availability_zone = "us-east-1a"

  tags {
    Name = "Private-Subnet-1"
    "kubernetes.io/cluster/Kubernetes" = "shared"
  }
}

resource "aws_subnet" "private-subnet-2" {
  cidr_block        = "${var.private_subnet_2_cidr}"
  vpc_id            = "${aws_vpc.production-vpc.id}"
  availability_zone = "us-east-1b"

  tags {
    Name = "Private-Subnet-2"
    "kubernetes.io/cluster/Kubernetes" = "shared"
  }
}

resource "aws_subnet" "private-subnet-3" {
  cidr_block        = "${var.private_subnet_3_cidr}"
  vpc_id            = "${aws_vpc.production-vpc.id}"
  availability_zone = "us-east-1c"

  tags {
    Name = "Private-Subnet-3"
    "kubernetes.io/cluster/Kubernetes" = "shared"
  }
}

resource "aws_route_table" "public-route-table" {
  vpc_id = "${aws_vpc.production-vpc.id}"
  tags {
    Name = "Public-Route-Table"
  }
}

resource "aws_route_table" "private-route-table" {
  vpc_id = "${aws_vpc.production-vpc.id}"
  tags {
    Name = "Private-Route-Table"
  }
}

resource "aws_route_table_association" "public-route-1-association" {
  route_table_id = "${aws_route_table.public-route-table.id}"
  subnet_id      = "${aws_subnet.public-subnet-1.id}"
}

resource "aws_route_table_association" "public-route-2-association" {
  route_table_id = "${aws_route_table.public-route-table.id}"
  subnet_id      = "${aws_subnet.public-subnet-2.id}"
}

resource "aws_route_table_association" "public-route-3-association" {
  route_table_id = "${aws_route_table.public-route-table.id}"
  subnet_id      = "${aws_subnet.public-subnet-3.id}"
}

resource "aws_route_table_association" "private-route-1-association" {
  route_table_id = "${aws_route_table.private-route-table.id}"
  subnet_id      = "${aws_subnet.private-subnet-1.id}"
}

resource "aws_route_table_association" "private-route-2-association" {
  route_table_id = "${aws_route_table.private-route-table.id}"
  subnet_id      = "${aws_subnet.private-subnet-2.id}"
}

resource "aws_route_table_association" "private-route-3-association" {
  route_table_id = "${aws_route_table.private-route-table.id}"
  subnet_id      = "${aws_subnet.private-subnet-3.id}"
}

resource "aws_eip" "elastic-ip-for-nat-gw" {
  vpc                       = true
  associate_with_private_ip = "10.0.0.5"

  tags {
    Name = "Production-EIP"
  }

  depends_on = ["aws_internet_gateway.production-igw"]
}

resource "aws_nat_gateway" "nat-gw" {
  allocation_id = "${aws_eip.elastic-ip-for-nat-gw.id}"
  subnet_id     = "${aws_subnet.public-subnet-1.id}"

  tags {
    Name = "Production-NAT-GW"
  }

  depends_on = ["aws_eip.elastic-ip-for-nat-gw"]
}

resource "aws_route" "nat-gw-route" {
  route_table_id         = "${aws_route_table.private-route-table.id}"
  nat_gateway_id         = "${aws_nat_gateway.nat-gw.id}"
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_internet_gateway" "production-igw" {
  vpc_id = "${aws_vpc.production-vpc.id}"
  tags {
    Name = "Production-IGW"
  }
}

resource "aws_route" "public-internet-igw-route" {
  route_table_id         = "${aws_route_table.public-route-table.id}"
  gateway_id             = "${aws_internet_gateway.production-igw.id}"
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_ecs_cluster" "production-fargate-cluster" {
  name = "Production-Fargate-Cluster"
}

resource "aws_security_group" "ecs_alb_security_group" {
  name        = "${var.ecs_cluster_name}-ALB-SG"
  description = "Security Group for ALB to traffic for ECS cluster"
  vpc_id      = "${aws_vpc.production-vpc.id}"

  ingress {
    from_port   = 443
    protocol    = "TCP"
    to_port     = 443
    cidr_blocks = ["${var.internet_cidr_blocks}"]
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["${var.internet_cidr_blocks}"]
  }
}

data "terraform_remote_state" "infrastructure" {
    backend = "s3"

config {
    region = "${var.region}"
    bucket = "${var.remote_state_bucket}"
    key    = "${var.remote_state_key}"
  }
}

resource "aws_alb" "ecs_cluster_alb" {
  name            = "${var.ecs_cluster_name}-ALB"
  internal        = false
  security_groups = ["${aws_security_group.ecs_alb_security_group.id}"]
  subnets         = ["${list(aws_subnet.public-subnet-1.id, aws_subnet.public-subnet-2.id, aws_subnet.public-subnet-3.id)}"]
  

  tags {
    Name = "${var.ecs_cluster_name}-ALB"
  }
}

resource "aws_acm_certificate" "ecs_domain_certificate" {
  domain_name       = "*.${var.ecs_domain_name}"
  validation_method = "DNS"

  tags {
    Name = "${var.ecs_cluster_name}-Certificate"
  }
}

data "aws_route53_zone" "ecs_domain" {
  name         = "${var.ecs_domain_name}"
  private_zone = false
}

resource "aws_route53_record" "ecs_cert_validation_record" {
  name    = "${aws_acm_certificate.ecs_domain_certificate.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.ecs_domain_certificate.domain_validation_options.0.resource_record_type}"
  zone_id = "${data.aws_route53_zone.ecs_domain.zone_id}"
  records = ["${aws_acm_certificate.ecs_domain_certificate.domain_validation_options.0.resource_record_value}"]
  ttl     = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "ecs_domain_certificate_validation" {
  certificate_arn = "${aws_acm_certificate.ecs_domain_certificate.arn}"
  validation_record_fqdns = ["${aws_route53_record.ecs_cert_validation_record.fqdn}"]
}


resource "aws_alb_listener" "ecs_alb_https_listener" {
  load_balancer_arn = "${aws_alb.ecs_cluster_alb.arn}"
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = "${aws_acm_certificate.ecs_domain_certificate.arn}"

  "default_action" {
    type              = "forward"
    target_group_arn  = "${aws_alb_target_group.ecs_default_target_group.arn}"
  }

  depends_on = ["aws_alb_target_group.ecs_default_target_group"]
}

resource "aws_alb_target_group" "ecs_default_target_group" {
  name      = "${var.ecs_cluster_name}-TG"
  port      = 80
  protocol  = "HTTP"
  vpc_id    = "${aws_vpc.production-vpc.id}"

  tags {
    Name = "${var.ecs_cluster_name}-TG"
  }
}

resource "aws_route53_record" "ecs_load_balancer_record" {
  name    = "*.${var.ecs_domain_name}"
  type    = "A"
  zone_id = "${data.aws_route53_zone.ecs_domain.zone_id}"

  alias {
    evaluate_target_health  = false
    name                    = "${aws_alb.ecs_cluster_alb.dns_name}"
    zone_id                 = "${aws_alb.ecs_cluster_alb.zone_id}"
  }
}

resource "aws_iam_role" "ecs_cluster_role" {
  name                = "${var.ecs_cluster_name}-IAM-Role"
  assume_role_policy  = <<EOF
{
"Version": "2012-10-17",
"Statement": [
  {
    "Effect": "Allow",
    "Principal": {
      "Service": ["ecs.amazonaws.com", "ec2.amazonaws.com", "application-autoscaling.amazonaws.com"]
    },
    "Action": "sts:AssumeRole"
  }
  ]
}
EOF
}

resource "aws_iam_role_policy" "ecs_cluster_policy" {
  name    = "${var.ecs_cluster_name}-IAM-Policy"
  role    = "${aws_iam_role.ecs_cluster_role.id}"
  policy  = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:*",
        "ec2:*",
        "elasticloadbalancing:*",
        "ecr:*",
        "dynamodb:*",
        "cloudwatch:*",
        "s3:*",
        "rds:*",
        "sqs:*",
        "sns:*",
        "logs:*",
        "ssm:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}
resource "aws_iam_role" "fargate_iam_role" {
  name                = "Fargate-IAM-Role"
  assume_role_policy  = <<EOF
{
"Version": "2012-10-17",
"Statement": [
  {
    "Effect": "Allow",
    "Principal": {
      "Service": ["ecs.amazonaws.com", "ecs-tasks.amazonaws.com"]
    },
    "Action": "sts:AssumeRole"
  }
  ]
}
EOF
}

resource "aws_iam_role_policy" "fargate_iam_role_policy" {
  name    = "Fargate-IAM-Role-Policy"
  role    = "${aws_iam_role.fargate_iam_role.id}"

  policy  = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:*",
        "ecr:*",
        "logs:*",
        "cloudwatch:*",
        "elasticloadbalancing:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}


# resource "aws_security_group" "app_security_group" {
#   name        = "${var.ecs_service_name}-SG"
#   description = "Security group for springbootapp to communicate in and out"
#   vpc_id      = "${aws_vpc.production-vpc.id}"

#   ingress {
#     from_port   = 8080
#     protocol    = "TCP"
#     to_port     = 8080
#     cidr_blocks = ["${var.internet_cidr_blocks}"]
#   }

#   egress {
#     from_port   = 0
#     protocol    = "-1"
#     to_port     = 0
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags {
#     Name  = "${var.ecs_service_name}-SG"
#   }
# }

# resource "aws_ecs_service" "ecs_service" {
#   name            = "${var.ecs_service_name}"
#   task_definition = "${var.ecs_service_name}"
#   desired_count   = "2"
#   cluster         = "Production-ECS-Cluster"
#   launch_type     = "FARGATE"

#   network_configuration {
#     subnets           = ["${list(aws_subnet.public-subnet-1.id, aws_subnet.public-subnet-2.id, aws_subnet.public-subnet-3.id)}"]
#     security_groups   = ["${aws_security_group.ecs_alb_security_group.id}"]
#     assign_public_ip  = true
#   }

#   # load_balancer {
#   #   container_name    = "${var.ecs_service_name}"
#   #   container_port    = "${var.docker_container_port}"
#   #   target_group_arn  = "${aws_alb_target_group.ecs_app_target_group.arn}"
#   # }
# }

resource "aws_eks_cluster" "Ira_Kub" {
  name     = "Kubernetes"
  role_arn = "${aws_iam_role.example.arn}"

  vpc_config {
    subnet_ids = ["${list(aws_subnet.public-subnet-1.id, aws_subnet.public-subnet-2.id, aws_subnet.public-subnet-3.id)}"]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  
  depends_on = [
    "aws_iam_role_policy_attachment.example-AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.example-AmazonEKSServicePolicy",
  ]
}


resource "aws_iam_role" "example" {
  name = "eks-cluster-kubernetes"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.example.name}"
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.example.name}"
}


# resource "aws_eks_fargate_profile" "eks_fargate_profile" {
#   cluster_name           = "${var.eks_cluster_name}" 
#   fargate_profile_name   = "eksfargate"
#   pod_execution_role_arn = "${aws_iam_role.example.arn}"
#   subnet_ids             = ["${list(aws_subnet.public-subnet-1.id, aws_subnet.public-subnet-2.id, aws_subnet.public-subnet-3.id)}"]

#   selector {
#     namespace = "eksfargate"
#   }
# }

# resource "aws_iam_role" "eks-fargate-kubernetes" {
#   name = "eks-fargate-profile-kubernetes"
#   assume_role_policy = <<POLICY
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "Service": "eks-fargate-pods.amazonaws.com"
#       },
#       "Action": "sts:AssumeRole"
#     }
#   ]
# }
# POLICY
# }

# resource "aws_iam_role_policy_attachment" "EKSFargate-AmazonEKSFargatePodExecutionRolePolicy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
#   role       = "${aws_iam_role.eks-fargate-kubernetes.name}"
# }


resource "kubernetes_service_account" "tiller_sa" {
  metadata {
    name      = "tiller"
    namespace = "kube-system"
  }
}

# resource "kubernetes_cluster_role_binding" "tiller_sa_cluster_admin_rb" {
#   metadata {
#     #name = "tiller-cluster-role"
#     name = "Kubernetes"
#   }
#   role_ref {
#     kind      = "ClusterRole"
#     name      = "Kubernetes"
#     api_group = "rbac.authorization.k8s.io"
#   }
#   subject {
#     kind      = "User"
#     name      = "admin"
#     api_group = "rbac.authorization.k8s.io"
#   }
#   subject {
#     kind      = "ServiceAccount"
#     name      = "${kubernetes_service_account.tiller_sa.metadata.0.name}"
#     namespace = "monitoring"
#     api_group = ""
#   }
#   subject {
#     kind      = "ServiceAccount"
#     name      = "${kubernetes_service_account.tiller_sa.metadata.0.name}"
#     namespace = "kube-system"
#     api_group = ""
#   }
# subject {
#     api_group = "rbac.authorization.k8s.io"
#     kind      = "User"
#     name      = "system:serviceaccount:kube-system:tiller"
#     namespace = "monitoring"
#   }
# }

resource "kubernetes_cluster_role_binding" "tiller" {
  metadata {
    name = "tiller"
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name      = "system:serviceaccount:kube-system:tiller"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind  = "ClusterRole"
    name = "cluster-admin"
  }
  #depends_on = ["aws_eks_cluster.Ira_Kub"]
}


resource "null_resource" "helm_init" {
  provisioner "local-exec" {
    command = "helm init --service-account tiller"
  }
  depends_on = ["aws_eks_node_group.example"]
}


resource "null_resource" "kubectl_init" {
  provisioner "local-exec" {
    command = "aws eks --region us-east-1 update-kubeconfig --name Kubernetes"
  }
  depends_on = ["aws_eks_cluster.Ira_Kub"]
}


provider "helm" {
  install_tiller  = true
  #version         = "< 1.0.0"
  namespace       = "kube-system"
  service_account = "tiller"
  tiller_image    = "gcr.io/kubernetes-helm/tiller:v2.11.0"
  debug           = "true"
  home            = "${var.helm_home}"
  #home            = "./.helm"

  kubernetes {
    config_path = "/home/ubuntu/.kube/config"
  }
}

# resource "local_file" "chart_config" {
#   content  = "Prometheus"
#   filename = "/home/ubuntu/prometheus/prometheus/values.yaml"
# }

data "helm_repository" "stable" {
  name = "stable"
  url  = "https://kubernetes-charts.storage.googleapis.com"
}


resource "helm_release" "prometheus" {
  name  = "prometheus"
  repository = "data.helm_repository.stable.metadata[0].name"
  #repository = "data.helm_repository.stable.metadata[0].url"
  chart = "stable/prometheus"
  version    = "11.1.2"
  namespace  = "monitoring"
  values = ["${file("/home/ubuntu/prometheus/prometheus/values.yaml")}"]
  timeout = 300
  depends_on = ["kubernetes_service_account.tiller_sa", "kubernetes_cluster_role_binding.tiller", "null_resource.helm_init"]
  depends_on = ["aws_eks_node_group.example"]
}


resource "aws_eks_node_group" "example" {
  cluster_name    = "${aws_eks_cluster.Ira_Kub.name}"
  node_group_name = "example1"
  node_role_arn   = "${aws_iam_role.eks-node-group.arn}"
  subnet_ids      = ["${list(aws_subnet.private-subnet-1.id, aws_subnet.private-subnet-2.id, aws_subnet.private-subnet-3.id)}"]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }
  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    "aws_iam_role_policy_attachment.example-AmazonEKSWorkerNodePolicy",
    "aws_iam_role_policy_attachment.example-AmazonEKS_CNI_Policy",
    "aws_iam_role_policy_attachment.example-AmazonEC2ContainerRegistryReadOnly",
  ]
}

resource "aws_iam_role" "eks-node-group" {
  name = "eks-node-group-example"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.eks-node-group.name}"
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.eks-node-group.name}"
}

resource "aws_iam_role_policy_attachment" "example-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.eks-node-group.name}"
}

