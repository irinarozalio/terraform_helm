
# outputs.tf

output "alb_hostname" {
  value = "${aws_alb.ecs_cluster_alb.dns_name}"
}