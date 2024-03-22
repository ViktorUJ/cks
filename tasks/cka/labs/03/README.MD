We have an  application (deployment, service , ingress) in namespace  **meg**. You can check the app via command  `curl http://ckad.local:30102/app` 

Yun need create new deployment,service, ingress  in namespace  **meg** 
 - deployment : name ` meg-app2` , env:  name: `SERVER_NAME` and  value: `megApp2` , all other parameters  copy from  `meg-app` deployment
 - service : name  ` meg-app2`   -> deployment ` meg-app2` 
 - ingress : name  ` meg-app2`   -> service ` meg-app2`  , route to the same address  `curl http://ckad.local:30102/app`  but with header `appVersion=2`

The application fetches tasks for processing from a queue (Kafka).
We need to create **Horizontal Pod Autoscaling** based on **CPU** load.
When the CPU load rises to **100%** we need to increase the number of pods to **6**.
The **minimum** amount of pods should be **2**.
