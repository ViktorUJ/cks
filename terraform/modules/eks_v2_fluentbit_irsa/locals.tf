locals {
  USER_ID      = var.USER_ID == "" ? "defaultUser" : var.USER_ID
  ENV_ID       = var.ENV_ID == "" ? "defaultId" : var.ENV_ID
  prefix_id    = "${local.USER_ID}_${local.ENV_ID}"
  prefix       = "${local.prefix_id}_${var.prefix}"
  item_id_lock = "CMDB_lock_${local.USER_ID}_${local.ENV_ID}_${var.app_name}_${var.prefix}"
  item_id_data = "CMDB_data_${local.USER_ID}_${local.ENV_ID}_${var.app_name}_${var.prefix}"

  # OIDC issuer host/path without https://, used in StringEquals keys of the IRSA trust policy
  oidc_provider = replace(data.aws_iam_openid_connect_provider.this.url, "https://", "")

  fluent_bit_namespace       = coalesce(var.fluent_bit.namespace, "amazon-cloudwatch")
  fluent_bit_service_account = coalesce(var.fluent_bit.service_account_name, "aws-for-fluent-bit")

  # Predictable log group name a la chapter 34: /aws/eks/<cluster>/application. Fluent Bit
  # creates it itself on first write (auto_create_group true), this ARN only scopes the role.
  log_group_name = coalesce(var.fluent_bit.log_group_name, "/aws/eks/${var.name}/application")

  role_name = "${var.prefix}-fluentbit-irsa-role"
}
