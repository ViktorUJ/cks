data "aws_subnet_ids" "example" {
  vpc_id = var.vpc_id
}
data "aws_availability_zones" "available" {
  state = "available"
}