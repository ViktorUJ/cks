resource "aws_autoscaling_group" "ec2_asg" {
  launch_template {
    id      = lt-0132c82cc706f4cfc
    version = "$Latest"
  }
  name = "server"
  vpc_zone_identifier = "vpc-0faeccad38aae3f0c"
  min_size            = 1
  max_size            = 3
  desired_capacity    = 1
  health_check_type   = "EC2"
  health_check_grace_period = 300


  target_group_arns = [aws_lb_target_group.app_target_group.arn]


  lifecycle {
    create_before_destroy = true
  }
}