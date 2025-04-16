# Detect and Stop Unauthorized Memory Access

Allowed resources:

- Kubernetes docs: https://kubernetes.io/docs/home/

- Falco docs: https://falco.org/docs/

|       **28**        | **Detect and Stop Unauthorized Memory Access**                                                                                                                                                                                                                               |
| :-----------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Acceptance criteria | There are different pods in the `north` namespace managed by different deployments. One pod in that namespace is attempting to access `/dev/mem`, which is a potential security risk. Your task is to identify the pod using falco and scale down the associated deployment. |
