# Cilium NetworkPolicy  L7.



You have a corporate portal ( k8s service **portal** in **production** namespace)

You need to create  [Cilium NetworkPolicy](https://editor.networkpolicy.io/) **api-access** provide these requirements 

the portal  APIs: 

/public/*  - open to all
/private/* - open from the finance namespace

for checking access you can use curl from pod in  the **finance** namespace or **external**  namespace

like this:


```
# private api
k exec  -n finance finance-855d98bddb-8kkdg  --  curl http://portal.production/private/api --connect-timeout 1

# public api
k exec  -n finance finance-855d98bddb-8kkdg  --  curl http://portal.production/public/api  --connect-timeout 1
```