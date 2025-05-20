[Kubernetes resource orchestration (kro) ](https://cloud.google.com/blog/products/containers-kubernetes/introducing-kube-resource-orchestrator)

- install kro +
- create CustomResource   with
  - ns  - app
  - deployment   app-prod  image viktoruj/ping_pong  , tag  , replicas , 
  - service app-prod   port 8080
  - ingress  , host cka.local  

- deploy the custom resource