# Install Cilium with WireGuard
[install cilium cli](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#install-the-cilium-cli)

You have a k8s cluster installed with kubeadm without kube-proxy .
Use [documentation](https://docs.cilium.io/en/stable/security/network/encryption-wireguard/) to install Cilium with WireGuard.


|        **1**        | **Install Cilium with WireGuard**                                                                                                                                                                                                                                               |
| :-----------------: |:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Acceptance criteria | -  Cilium is installed  <br/>- encryption.enabled : `true` <br/>- encryption.type : **true** <br/>- nodes are **ready** <br/>- traffic between pod **external** in NS **external** and service **finance** in NS **finance** (pod **finance** in NS **finance** )  is encrypted |
---

For check use tcpdump on  nodes

check pods communication
```
k exec external -n external  --  sh -c 'curl finance.finance:8080'
```
