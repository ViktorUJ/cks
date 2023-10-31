locals {
  subnets            = var.eks.subnets
  availability_zones = var.eks.az_ids
  cluster_name       = "${var.aws}-${var.prefix}"

}
