# Модуль не зависит от OIDC-провайдера кластера: роль AWS Backup доверяет сервисному
# principal backup.amazonaws.com (aws_iam_role.backup), а не ServiceAccount через IRSA.
data "aws_partition" "current" {}
