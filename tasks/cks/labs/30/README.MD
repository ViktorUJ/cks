# Create istio network policy

Allowed resources:

- [Kubernetes docs](https://kubernetes.io/docs/home/)

- [Istio docs](https://istio.io/latest/)  

- [Istio peer_authentication](https://istio.io/latest/docs/reference/config/security/peer_authentication/)



- **istio cli** is installed on **control-plane** node


|       **30**        | **Configure istio network policies with**  <br/>   **istio cli** is installed on **control-plane** node                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
|:-------------------:|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Acceptance criteria | You have to develop Istio mTLS policy in `market` namespace:<br/> 1. You have to configure istio mTLS in `market` namespace.<br/> 2. Enforce Mutual Authentication between pods in `market` namespace.<br/> 3. To check that policy is working, you can run:<br/>`kubectl exec -it tester -- curl app.market.svc.cluster.local:8080 --head`  <br/> # Curl from default namespace   curl: (56) Recv failure: Connection reset by peer <br/>`kubectl exec -n market -it db -- curl app.market.svc.cluster.local:8080 --head` <br/> # From db pod  HTTP/1.1 200 OK <br/>`kubectl exec -n market -it app -- curl app.market.svc.cluster.local:8080 --head` <br/> # From app pod  HTTP/1.1 200 OK |

[solution](worker/files/solutions/1.MD)