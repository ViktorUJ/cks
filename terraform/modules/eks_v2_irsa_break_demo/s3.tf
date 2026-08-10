# S3 bucket used by the IRSA demo pod. Name is predictable (prefix + app_name), so the
# worker can find it by name without reading terraform output.
resource "aws_s3_bucket" "demo" {
  bucket = local.bucket_name
  tags   = merge(var.tags, { "Name" = local.bucket_name })
}

resource "aws_s3_bucket_public_access_block" "demo" {
  bucket = aws_s3_bucket.demo.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "demo_object" {
  bucket       = aws_s3_bucket.demo.id
  key          = "hello.txt"
  content      = "hello from s3\n"
  content_type = "text/plain"
}
