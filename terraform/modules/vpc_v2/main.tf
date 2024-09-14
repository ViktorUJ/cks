
module "vpc" {
  depends_on           = [aws_dynamodb_table_item.cmdb]
  source = "ViktorUJ/vpc/aws"
  tags_default = var.tags_common
  vpc = {
    name = "${var.prefix}-${var.USER_ID}-${var.ENV_ID}-${var.STACK_NAME}-${var.STACK_TASK}"
    cidr = var.vpc_default_cidr
  }

  subnets = {
    public = {
      "pub1" = {
        name = "public-subnet-1"
        cidr = "10.10.1.0/24"
        az   = "eu-north-1a"
      }
      "pub2" = {
        name = "public-subnet-2"
        cidr = "10.10.2.0/24"
        az   = "eu-north-1a"
      }

    }
  }
}