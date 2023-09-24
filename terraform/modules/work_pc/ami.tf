data "aws_ec2_instance_type" "master" {
  instance_type = var.work_pc.instance_type
}
output "arch" {
  value = join("",data.aws_ec2_instance_type.master.supported_architectures)
}

data "aws_ami" "master" {

# most_recent = true

  filter {
    name   = "name"
    values = [
#      "ubuntu/images/hvm-ssd/ubuntu-*-${var.work_pc.ubuntu_version}-${join("",data.aws_ec2_instance_type.master.supported_architectures)}-server-*"
      "ubuntu/images/hvm-ssd/ubuntu-*-${var.work_pc.ubuntu_version}-*-server-*"
    ]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

output "ami" {
  value = data.aws_ami.master
}