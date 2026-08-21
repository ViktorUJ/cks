# Bucket for the Mountpoint for Amazon S3 CSI driver demo. Only static provisioning is
# supported by the driver, so the bucket has to exist before the PV is created by hand.
# Name is predictable (prefix + fixed suffix), so the worker can find it without reading
# terraform output.
resource "aws_s3_bucket" "mountpoint_demo" {
  bucket = local.bucket_name
  tags   = merge(var.tags, { "Name" = local.bucket_name })
}

resource "aws_s3_bucket_public_access_block" "mountpoint_demo" {
  bucket = aws_s3_bucket.mountpoint_demo.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning is the actual data-protection mechanism for objects behind this PVC: there is
# no EBS-style snapshot for a Mountpoint volume (see chapter 41/lab task 6), so protection
# against accidental overwrite or delete comes from S3 bucket versioning instead.
resource "aws_s3_bucket_versioning" "mountpoint_demo" {
  bucket = aws_s3_bucket.mountpoint_demo.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_object" "readme" {
  bucket       = aws_s3_bucket.mountpoint_demo.id
  key          = "readme.txt"
  content      = "mountpoint demo bucket\n"
  content_type = "text/plain"

  # keep the object even if bucket versioning creates new versions on re-apply
  lifecycle {
    ignore_changes = [content]
  }
}
