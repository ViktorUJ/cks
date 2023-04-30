````` 
 mkdir /etc/admission-controllers/
 
`````


```` 
#  vim /etc/admission-controllers/admission-configuration.yaml


apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ImagePolicyWebhook
  configuration:
    imagePolicy:
      kubeConfigFile: /etc/admission-controllers/admission-kubeconfig.yaml
      allowTTL: 50
      denyTTL: 50
      retryBackoff: 500
      defaultAllow: false
````

```` 
## add  to  api 


    - --admission-control-config-file=/etc/admission-controllers/admission-configuration.yaml
    - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook

......
  volumeMounts:
  - mountPath: /etc/admission-controllers
      name: admission-controllers
      readOnly: true

  volumes:
  - hostPath:
      path: /root/CKS/ImagePolicy/
      type: DirectoryOrCreate
    name: admission-controllers
````

````` 
# /etc/admission-controllers/admission-configuration.yaml

`````