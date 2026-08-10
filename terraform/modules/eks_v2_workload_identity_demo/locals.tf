locals {
  USER_ID      = var.USER_ID == "" ? "defaultUser" : var.USER_ID
  ENV_ID       = var.ENV_ID == "" ? "defaultId" : var.ENV_ID
  prefix_id    = "${local.USER_ID}_${local.ENV_ID}"
  prefix       = "${local.prefix_id}_${var.prefix}"
  item_id_lock = "CMDB_lock_${local.USER_ID}_${local.ENV_ID}_${var.app_name}_${var.prefix}"
  item_id_data = "CMDB_data_${local.USER_ID}_${local.ENV_ID}_${var.app_name}_${var.prefix}"

  # OIDC issuer host/path without https://, used in StringEquals keys of the IRSA trust policy
  oidc_provider = replace(data.aws_iam_openid_connect_provider.this.url, "https://", "")

  bucket_name = "${var.prefix}-${var.app_name}-bucket"
  secret_name = "${var.prefix}-${var.app_name}-secret"
  irsa_role_name          = "${var.prefix}-${var.app_name}-irsa-role"
  pod_identity_role_name  = "${var.prefix}-${var.app_name}-pod-identity-role"
}
