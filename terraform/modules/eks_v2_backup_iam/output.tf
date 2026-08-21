output "role_arn" {
  value = aws_iam_role.backup.arn
}

output "role_name" {
  value = aws_iam_role.backup.name
}

output "vault_name" {
  value = aws_backup_vault.this.name
}

output "vault_arn" {
  value = aws_backup_vault.this.arn
}

output "kms_key_arn" {
  value = aws_kms_key.backup.arn
}
