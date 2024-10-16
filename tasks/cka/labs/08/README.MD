# Cilium NetworkPolicy  L7.

You have a corporate portal ( k8s service **portal** in **production** namespace)

Нou need to create  Cilium NetworkPolicy **api-access** provide these requirements 

the portal  APIs: 

/public/*  - open to all
/private/* - open from the finance namespace

