data "aws_ec2_instance_type" "test" {
  instance_type = var.node_type
}
output "aws_ec2_instance_type" {
  value = data.aws_ec2_instance_type.test.supported_architectures
}