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

locals {
 worker_ami_arh= {
   for key, instance in var.k8s_worker:
   key =>{
     name = join("",data.aws_ec2_instance_type.master.supported_architectures) == "x86_64" ? "amd64" : "arm64"
     filter = join("",data.aws_ec2_instance_type.master.supported_architectures) == "x86_64" ? "ubuntu/images/hvm-ssd/ubuntu-*-${instance.ubuntu_version}-amd64-server-*" : "ubuntu/images/hvm-ssd/ubuntu-*-${instance.ubuntu_version}-arm64-server-*"
   }
 }
}

output "worker_arch" {
  value = local.worker_ami_arh
}
#data "aws_ami" "worker" {
#  for_each    = var.k8s_worker
#  most_recent = true
#
#  filter {
#    name   = "name"
#    values = ["ubuntu/images/hvm-ssd/ubuntu-*-${each.value.ubuntu_version}-${local.worker_ami_arh["$key"].name}-server-*"]
#  }
#
#  filter {
#    name   = "virtualization-type"
#    values = ["hvm"]
#  }
#
#  owners = ["099720109477"]
#}
#
