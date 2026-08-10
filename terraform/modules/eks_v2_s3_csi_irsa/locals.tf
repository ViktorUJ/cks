locals {
  USER_ID      = var.USER_ID == "" ? "defaultUser" : var.USER_ID
  ENV_ID       = var.ENV_ID == "" ? "defaultId" : var.ENV_ID
  prefix_id    = "${local.USER_ID}_${local.ENV_ID}"
  prefix       = "${local.prefix_id}_${var.prefix}"
  item_id_lock = "CMDB_lock_${local.USER_ID}_${local.ENV_ID}_${var.app_name}_${var.prefix}"
  item_id_data = "CMDB_data_${local.USER_ID}_${local.ENV_ID}_${var.app_name}_${var.prefix}"

  # OIDC issuer host/path without https://, used in StringEquals keys of the trust policy
  oidc_provider = replace(data.aws_iam_openid_connect_provider.this.url, "https://", "")

  # Default ServiceAccount name that the aws-mountpoint-s3-csi-driver addon uses
  s3_csi_namespace       = "kube-system"
  s3_csi_service_account = "s3-csi-driver-sa"

  bucket_name = "${var.prefix}-mountpoint-demo"
}
