# --- Network breakage demo (chapter 46): security group with a correct description but
# ZERO inbound rules. This is the whole "break": outbound is allowed (SG is stateful, so a
# response to an outbound request comes back on its own, chapter 46.3), but nobody can open
# a NEW connection INTO whatever this SG gets attached to. The lab attaches this SG as the
# load balancer's own security group (Service annotation aws-load-balancer-security-groups),
# so the NLB health check to the node SG has no matching inbound rule and targets go
# unhealthy (chapter 46.6). The student diagnoses it and fixes it with a single
# `aws ec2 authorize-security-group-ingress` call.
resource "aws_security_group" "network_break" {
  name        = local.sg_name
  description = "Lab 120: allows app traffic on 8080 from the cluster - intentionally empty on create, fix by adding the ingress rule"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { "Name" = local.sg_name })

  lifecycle {
    # Ignore rule drift: the student is expected to add an ingress rule with the AWS CLI
    # (aws ec2 authorize-security-group-ingress) outside of terraform. Re-applying this
    # module must not silently revert the student's fix.
    ignore_changes = [ingress]
  }
}

# Outbound is allowed on purpose (matches the stateful SG behavior from chapter 46.3): this
# keeps the demo focused on the missing INBOUND rule, which is the actual symptom.
resource "aws_vpc_security_group_egress_rule" "network_break_all_outbound" {
  security_group_id = aws_security_group.network_break.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound (SG is stateful, chapter 46.3)"
}
