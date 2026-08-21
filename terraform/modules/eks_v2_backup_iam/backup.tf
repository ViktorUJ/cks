# AWS Backup для EKS (глава 41): роль, от имени которой сервис читает состояние кластера
# и связанные тома, и vault, куда складываются recovery points. Никакого агента или
# аддона в кластер эта роль не требует - AWS Backup работает через Kubernetes API,
# опираясь на access entry, которую сам создаёт при режиме authentication_mode
# API/API_AND_CONFIG_MAP (см. terraform/modules/eks_v2_control_plane/eks.tf).

# --- IAM Role для AWS Backup (trust policy на сервисный principal) ---
resource "aws_iam_role" "backup" {
  name = "${var.name}-backup"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "backup.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

# AWSBackupServiceRolePolicyForBackup - обязательна для backup job (глава 41, раздел 41.3).
# Обе политики AWS Backup лежат в пути service-role/, без него AttachRolePolicy отвечает
# NoSuchEntity: "policy does not exist or is not attachable".
resource "aws_iam_role_policy_attachment" "backup_for_backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# AWSBackupServiceRolePolicyForRestores - обязательна для restore job (глава 42, раздел 42.2).
resource "aws_iam_role_policy_attachment" "backup_for_restores" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# --- Backup vault: хранилище recovery points со своим ключом KMS (глава 41, раздел 41.6) ---
resource "aws_kms_key" "backup" {
  description             = "KMS key for AWS Backup vault of ${var.name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_kms_alias" "backup" {
  name          = "alias/${var.name}-backup"
  target_key_id = aws_kms_key.backup.key_id
}

resource "aws_backup_vault" "this" {
  name        = "${var.name}-vault"
  kms_key_arn = aws_kms_key.backup.arn
  tags        = var.tags
}
