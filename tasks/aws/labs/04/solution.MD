- create iam role **server**  for ec2
- attach iam policy **AmazonSSMManagedInstanceCore** to the role
- attach the role to the instance
- connect via ssm session manager

- The instance should have installed SSM agent
- if ec2 is in private subnet, it should have endpoint ssm endpoints  (**ssm** ,  **ssmmessages**  and  **ec2messages**)
- endpoint security groups should allow traffic from vpc cidr





