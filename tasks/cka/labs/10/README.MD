[Kubernetes resource orchestration (kro) ](https://cloud.google.com/blog/products/containers-kubernetes/introducing-kube-resource-orchestrator)

github: [kro](https://github.com/kro-run/kro/tree/main)

- install kro
- create ResourceGraphDefinition   with
  - ns  - app
  - deployment   app-prod  image viktoruj/ping_pong  , tag  , replicas , 
  - service app-prod   port 8080
  - ingress  , host cka.local  

- deploy the custom resource
- check the deployment  , pods, services, ingress
- scale replicas to 3 via custom resource
- check application via request to ingress host  `curl cka.local:30102`
- delete the custom resource

[solution](worker/files/solutions/1.MD)
