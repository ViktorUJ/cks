provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "terraform_remote" {
  bucket = var.s3_backet
  lifecycle {
   prevent_destroy = true
  }


}

resource "aws_s3_bucket_versioning" "terraform_remote" {
  bucket = aws_s3_bucket.terraform_remote.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "dynamodb-state-lock" {
  name           = "${var.s3_backet}-lock"
  hash_key       = "LockID"
  read_capacity  = 1
  write_capacity = 1

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
   prevent_destroy = true
  }

  tags = {
    Name = "DynamoDB Terraform  Lock Table for ${var.s3_backet}"
    project = "infra"
  }
}


