# Create cilium network policy

Allowed resources:

- Kubernetes docs: https://kubernetes.io/docs/home/

- Cilium docs: https://docs.cilium.io/en/stable/

- https://docs.cilium.io/en/latest/network/servicemesh/mutual-authentication/mutual-authentication-example/

|       **27**        | **Configure cilium network policies with**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| :-----------------: |:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Acceptance criteria | **cilium cli** is installed on **control-plane** node <br/> You have to develop Cilium network policy in `myapp` namespace:<br/>&nbsp;&nbsp;1. You have to configure cilium network policy to allow access from pods in `ingress-nginx` namespace to our app deployed in `myapp` namespace.<br/>&nbsp;&nbsp;2. Enforce Mutual Authentication between pods in `ingress-nginx` and our app in `myapp` namespace.<br/>&nbsp;&nbsp; To check that policy is working, you can run `curl --connect-timeout 1 --max-time 1 -s http://myapp.local:30800 -v ` should work without any problems. |
