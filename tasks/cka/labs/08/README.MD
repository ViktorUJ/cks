# Cilium NetworkPolicy  L7.



You have a corporate portal ( k8s service **portal** in **production** namespace)

You need to create  [Cilium NetworkPolicy](https://editor.networkpolicy.io/) **api-access** provide these requirements


[docs](https://docs.cilium.io/en/v1.10/policy/language/#l7-layer-7-policies)


[examples](https://github.com/cilium/cilium/tree/main/examples/policies/getting-started)

the portal  **APIs**:

/public/*  - open all **method**  from  all cluster


/private/* - open all **method** from all in  **finance** namespace


for checking access you can use curl from pod in  the **finance** namespace or **external**  namespace

like this:

### **private** api from **finance** namespace
```
k exec  -n finance finance  --  curl http://portal.production/private/api123 --connect-timeout 1
```
### **public** api from **finance** namespace
```
k exec  -n finance finance  --  curl http://portal.production/public/api123  --connect-timeout 1
```

### **private** api from **external** namespace
```
k exec  -n external external  --  curl http://portal.production/private/api123 --connect-timeout 1
```
### **public** api from **external** namespace
```
k exec  -n external external  --  curl http://portal.production/public/api123  --connect-timeout 1
```
