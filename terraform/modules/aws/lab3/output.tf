output "subnets" {
  value = var.subnets
}


output "asg" {
  value = aws_autoscaling_group.ec2_asg.id
}

output "alb" {
  value = aws_lb.app_lb.dns_name
}