## Network policy

1. create  default deny policy(ingress egress) in prod-stack-1 NS
2. create default deny policy in prod-db NS
3. create  policy with allow access from user-client  NS  to frontend pods in  prod-stack-1 NS
4. create  policy with allow access from  frontend pods  prod-stack-1 NS  to  backend pods in  prod-stack-1 NS
5. create  policy with allow access from   backend pods   prod-stack-1 NS  to  mysql pods in prod-db  NS

