# EFS - региональная файловая система. Терраформ создаёт её заранее: драйвер
# aws-efs-csi-driver работает поверх существующей ФС по fileSystemId, сам файловую
# систему не создаёт.
resource "aws_efs_file_system" "this" {
  creation_token = "${var.prefix}-efs"
  encrypted      = true

  tags = merge(var.tags, { "Name" = "${var.prefix}-efs" })
}

# Security group для mount target: разрешаем NFS (2049) только от security group нод
# кластера, иначе монтирование зависает по таймауту (FailedMount).
resource "aws_security_group" "efs_mount_target" {
  name        = "${var.prefix}-efs-mt"
  description = "EFS mount targets - NFS 2049 from EKS node security group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { "Name" = "${var.prefix}-efs-mt" })
}

resource "aws_vpc_security_group_ingress_rule" "nfs_from_nodes" {
  security_group_id            = aws_security_group.efs_mount_target.id
  referenced_security_group_id = var.security_group_source_id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
  description                  = "NFS from EKS node security group"
}

resource "aws_vpc_security_group_egress_rule" "all_out" {
  security_group_id = aws_security_group.efs_mount_target.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound"
}


# Mount target по одному на каждую подсеть (AZ) из списка. Без mount target в AZ поды
# в этой зоне не смогут примонтировать том.
resource "aws_efs_mount_target" "this" {
  for_each = toset(var.subnet_ids)

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs_mount_target.id]
}
