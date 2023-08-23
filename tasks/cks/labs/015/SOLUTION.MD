geterate cert 

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout cert.key -out cert.crt -subj "/CN=world.universe.mine/O=world.universe.mine"








Investigate
We can get the IP address of the Ingress and we see it's the same one to which `secure-ingress.test` is pointing to:

```sh
➜ k -n team-pink get ing secure 
NAME     CLASS    HOSTS                 ADDRESS          PORTS   AGE
secure   <none>   secure-ingress.test   192.168.100.12   80      7m11s
