resource "aws_instance" "server" {
    ami           = "ami-0129bfde49ddb0ed6"
    instance_type = "t3.micro"
    subnet_id     = var.subnets[0]
    vpc_security_group_ids = [aws_security_group.servers1.id]
    tags = merge(
        var.tags_common,
        {
        Name = "${var.prefix}-${var.app_name}-server"
        }
    )
}

resource "aws_instance" "server-private" {
    ami           = "ami-0129bfde49ddb0ed6"
    instance_type = "t3.micro"
    subnet_id     = var.subnets_private[0]
    vpc_security_group_ids = [aws_security_group.servers1.id]
    tags = merge(
        var.tags_common,
        {
        Name = "${var.prefix}-${var.app_name}-server-private"
        }
    )
}
