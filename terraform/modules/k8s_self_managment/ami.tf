data "aws_ec2_instance_type" "master" {
    instance_type = var.k8s_master.instance_type
}
locals {
    master_arch=join("",data.aws_ec2_instance_type.master.supported_architectures)
}
data "aws_ami" "master" {

    most_recent = true

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-*-${var.k8s_master.ubuntu_version}-${local.master_arch}-server-*"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }

    owners = ["099720109477"]
}

output "ami_master" {
  value = data.aws_ami.master
}

output "aws_ec2_instance_type" {
    value = local.master_arch
}