data "aws_ami" "master" {

   # most_recent = true

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-*-${var.k8s_master.ubuntu_version}-amd64-server-*"]
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