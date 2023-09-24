data "aws_ec2_instance_type" "master" {
  instance_type = var.k8s_master.instance_type
}

data "aws_ami" "master" {

  most_recent = true

  filter {
    name   = "name"
    values = join("",data.aws_ec2_instance_type.master.supported_architectures) == "x86_64" ? ["ubuntu/images/hvm-ssd/ubuntu-*-${var.k8s_master.ubuntu_version}-amd64-server-*" ] : ["ubuntu/images/hvm-ssd/ubuntu-*-${var.k8s_master.ubuntu_version}-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}


data "aws_ec2_instance_type" "worker" {
  for_each      = var.k8s_worker
  instance_type = each.value.instance_type
}

data "aws_ami" "worker" {
  for_each    = var.k8s_worker
  most_recent = true

  filter {
    name   = "name"
    values = join("",data.aws_ec2_instance_type.worker["${key}"].supported_architectures) == "x86_64" ? ["ubuntu/images/hvm-ssd/ubuntu-*-${each.value.ubuntu_version}-amd64-server-*" ] : ["ubuntu/images/hvm-ssd/ubuntu-*-${each.value.ubuntu_version}-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

