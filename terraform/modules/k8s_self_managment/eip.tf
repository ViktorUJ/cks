resource "aws_eip" "master" {
  for_each = toset(var.k8s_master.eip == "true" ? ["enable"] : [])
  vpc      = true
  tags     = local.tags_all_k8_master
}

resource "aws_eip_association" "master" {
  for_each      = toset(var.k8s_master.eip == "true" ? ["enable"] : [])
  instance_id   = local.master_instance_id
  allocation_id = aws_eip.master["enable"].id
}
