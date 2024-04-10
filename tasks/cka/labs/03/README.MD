We use the ingress nginx controller.
We have an  application (deployment, service , ingress) in namespace  **meg**. You can check the app via command  `curl http://ckad.local:30102/app` 

Yun need create new deployment,service, ingress  in namespace  **meg** 
 - deployment : name ` meg-app2` , env:  name: `SERVER_NAME` and  value: `megApp2` , all other parameters  copy from  `meg-app` deployment
 - service : name  ` meg-app2`   -> deployment ` meg-app2` 
 - ingress : name  ` meg-app2`   -> service ` meg-app2`  , route to the same address  `curl http://ckad.local:30102/app`  but with header `X-Appversion=v2`

check `    curl -H "X-Appversion: v2" http://ckad.local:30102/app    `