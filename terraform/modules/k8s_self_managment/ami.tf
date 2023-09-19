data "aws_ec2_instance_type" "master" {
    instance_type = var.k8s_master.instance_type
}
data "aws_ami" "master" {

    most_recent = true

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

output "aws_ec2_instance_type" {
    value = join("",data.aws_ec2_instance_type.master.supported_architectures)
}