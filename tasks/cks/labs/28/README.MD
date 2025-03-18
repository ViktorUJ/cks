# Detect and Stop Unauthorized Memory Access

Allowed resources:

- Kubernetes docs: https://kubernetes.io/docs/home/

- Falco docs: https://falco.org/docs/

|       **28**        | **Detect and Stop Unauthorized Memory Access**                                                                                                                                        |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Acceptance criteria | A pod in the north namespace is attempting to access `/dev/mem`, which is a potential security risk. Your task is to identify the pod using and scale down the associated deployment. |
