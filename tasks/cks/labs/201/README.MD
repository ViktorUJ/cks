## Network policy

1. create  default deny policy(ingress egress) in prod-stack-1 NS
2. create default deny policy in prod-db NS
3. create  policy with allow access from user-client  NS  to frontend pods in  prod-stack-1 NS
4. create  policy with allow access from  frontend pods  prod-stack-1 NS  to  backend pods in  prod-stack-1 NS
5. create  policy with allow access from   backend pods   prod-stack-1 NS  to  mysql pods in prod-db  NS


### test

````
#from backend pod
curl mysql.prod-db.svc --connect-timeout 1   -v   #  work 
curl google.com    --connect-timeout 1     -v     # not  work   (Network is unreachable)
curl frontend     --connect-timeout 1     -v # not work (Connection timed)


#from frontend  pod
curl  backend    --connect-timeout 1               # work 
curl mysql.prod-db.svc --connect-timeout 1   -v    #  not work 
curl google.com    --connect-timeout 1     -v      # not  work   




# from db pod 
curl backend.prod-stack-1.svc --connect-timeout 1   -v    #  not work 
curl google.com    --connect-timeout 1     -v      # not  work  
   
# from  user-client
curl frontend.prod-stack-1.svc --connect-timeout 1   -v    #   work 
curl backend.prod-stack-1.svc --connect-timeout 1   -v    #  not work 
curl mysql.prod-db.svc --connect-timeout 1   -v   # not work 
curl google.com    --connect-timeout 1     -v      # work   
    
   
````