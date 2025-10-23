
# Allowed resources
**Kubernetes Documentation:**

https://kubernetes.io/docs/ and their subdomains

https://kubernetes.io/blog/ and their subdomains

This includes all available language translations of these pages (e.g. https://kubernetes.io/zh/docs/)

**Tools:**

**Trivy** documentation https://aquasecurity.github.io/trivy/

**Falco** documentation https://falco.org/docs/
This includes all available language translations of these pages (e.g. https://falco.org/zh/docs/)

**App Armor**:
Documentation https://gitlab.com/apparmor/apparmor/-/wikis/Documentation

**Cilium** 
Documentation  https://docs.cilium.io/en/stable

**Istio**
Documentation https://istio.io/latest/docs/

**NGINX Ingress Controller**
Documentation  https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/

**Bom**
Documentation  https://kubernetes-sigs.github.io/bom/cli-reference/

**Etcd** 
documentation https://etcd.io/docs/


![preview](./preview.png)

- run ``time_left`` on work pc to **check time**
- run ``check_result`` on work pc to **check result**

# Questions

---
|        **1**        | **Perform Docker security configuration**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
|:-------------------:|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|        host         | ` ssh docker-worker`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| Acceptance criteria | In the host docker as a container engine. We need to perform the following tasks to enhance Docker security:<br/>&nbsp;&nbsp;- remove access to docker daemon for user `user`.<br/>Docker is being exposed through the TCP socket. This is considered as a high security risk. We need to stop exposing it and perform some security enhancements.<br/>&nbsp;&nbsp;- Docker socket `/var/run/docker.sock` is configured to be used for users that are in docker group. Change docker socket permissions to make it available only for `root` user and `root` group.<br/>Acceptance criteria:<br/>&nbsp;&nbsp;- `developer` user is not able to use docker anymore.<br/>&nbsp;&nbsp;- docker is NOT being exposed using TCP.<br/>&nbsp;&nbsp;- `docker.sock` has proper permissions. |
---

|        **2**        | Configure **istio**  policies  . <br/>   **istio cli** is installed on **control-plane** node                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
|:-------------------:|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|       Cluster       | cluster12 (`kubectl config use-context cluster12-admin@cluster12`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Acceptance criteria | You have to develop Istio mTLS policy in `market` namespace:<br/> 1. You have to configure istio mTLS in `market` namespace.<br/> 2. Enforce Mutual Authentication between pods in `market` namespace.<br/> 3. To check that policy is working, you can run:<br/>`kubectl exec -it tester -- curl app.market.svc.cluster.local:8080 --head`  <br/> # Curl from default namespace   curl: (56) Recv failure: Connection reset by peer <br/>`kubectl exec -n market -it db -- curl app.market.svc.cluster.local:8080 --head` <br/> # From db pod  HTTP/1.1 200 OK <br/>`kubectl exec -n market -it app -- curl app.market.svc.cluster.local:8080 --head` <br/> # From app pod  HTTP/1.1 200 OK |
---

|     **3**  надо     | **falco**  Detect and Stop Unauthorized Memory Access   . в фалко не видны k8 тэги .                                                                                                                                                                    |
|:-------------------:|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|       Cluster       | cluster8 (`kubectl config use-context cluster8-admin@cluster8`)                                                                                                                                                                                         |
| Acceptance criteria | There are different pods in k8s cluster with  managed by different deployments. One pod  is attempting to access `/dev/mem`, which is a potential security risk. Your task is to identify the pod using falco and scale down the associated deployment. |
---

|        **4**        | Create an **Ingress** with a redirect from **HTTP** to **HTTPS**                                                                                                                                                                                            |
|:-------------------:|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|       Cluster       | cluster6 (`kubectl config use-context cluster6-admin@cluster6`)                                                                                                                                                                                             |
| Acceptance criteria | - cert located `/var/work/19` <br/>- ns `team-19`  <br/> - Service  `team19` <br/> -ingress `team19` <br/> - check https  `curl https://cks.local:31139  -kvL` <br/> - certificate CN=**cks.local**  <br/>-   check redirect  `curl http://cks.local:30102` |
---

|         **5**       | **Network policy**                                                                                                                                                                                                                                                                                                                                                                                                                                           |
|:-------------------:|:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|       Cluster       | cluster6 (`kubectl config use-context cluster6-admin@cluster6`)                                                                                                                                                                                                                                                                                                                                                                                              |
| Acceptance criteria | - create default deny ingress policy in `prod-db` NS<br/>- create policy with allow connections from `prod` Namespaces to `prod-db`<br/>- create policy with allow connections from `stage` Namespaces and have label: `role=db-connect`<br/>- create policy with allow connections from `any` Namespaces and have label: `role=db-external-connect` <br/>- for test connections use **svc** in `prod-db` NS and pods in `stage` ,  `prod` and `default ` NS |
---

|         **6**       | **Deployment security**        user ID , эскалейшен  и рут реадонли .                                                                                                                          |
|:-------------------:|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|       Cluster       | cluster6 (`kubectl config use-context cluster6-admin@cluster6`)                                                                                                                                |
| Acceptance criteria | Modify deployment `secure` in `secure` Namespace:<br/>- prevent escalation<br/>- Read only root file system<br/>- user id 3000<br/>- group id 3000<br/>- allow wread to `/tmp/` container `c1` |
---

|        **7**        | disable sa secret auto-mount.  mount it to specific path.                                                                                                                                               |
|:-------------------:|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     **Cluster**     | cluster6 (`kubectl config use-context cluster6-admin@cluster6`)                                                                                                                                         |
| Acceptance criteria | - ns  team-20  , deployment `team20`   <br/> -  create sa `team20` <br/>- update deployment `team20` to use sa `team20` <br/> disable automount sa secret <br/> mount sa secret to `/var/team20/secret` |
---

|        **8**        | **Image Vulnerability Scanning**  bom    / в деплойменте несколько контейнеров . найти в каком имадже контейнера  содержится либа определенной верси . удалить этот контейнер из деплоймента . и для этого имаджа сохранить результат скана в определенном формате .                                                             |
|:-------------------:|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|       Cluster       | cluster6 (`kubectl config use-context cluster6-admin@cluster6`)                                                                                                                                                                                                                                                                  |
| Acceptance criteria | - delete all containers with `ca-certificates-bundle` version `20230506-r0` in deployment `deployment1` NS `team-xxx` using the `bom` utility.  <br/> -  Generate a SPDX-Json SBOM of image for `registry.k8s.io/kube-scheduler:v1.32.0` and store to `/var/work/02/kube_scheduler_sbom.json` using the `bom` utility. |
---

|        **9**        | **Pod Security Standard**   is enabled  in restricted mode on NS `team-red` . fix deployment |
|:-------------------:|:-----------------------------------------------------------------------------------|
|        Cluster      | cluster6 (   `kubectl config use-context    cluster6-admin@cluster6`   )           |
| Acceptance criteria | pod from  Deployment `container-host-hacker` in Namespace `team-red` is running .  |
---
|       **10**        | Create a TLS secret from local files. There is a Deployment with the appropriate volume mounts configured. Verify that the secret has appeared correctly inside the Pod.                            |
|:-------------------:|:-------------------------------------------------------------------------------------------------------------------------------------|
|       Cluster       | cluster6 (`kubectl config use-context cluster6-admin@cluster6`)                                                                      |
| Acceptance criteria | **NS** `team-black10`  , create  tls secret `tls` from  `/var/work/19` . pod from deployment `app` has mounted secret in file system |
---

|         **11**      | **update cluster** <br/>  In the cluster, the control plane node has been upgraded to the new version. It is necessary to upgrade the worker node |
|:-------------------:|:--------------------------------------------------------------------------------------------------------------------------------------------------|
|       Cluster       | cluster7 (`kubectl config use-context cluster7-admin@cluster7`)                                                                                   |
| Acceptance criteria | node is **ready** and **version** is the same with control-plane                                                                                  |
---





|     **3**    6      | **Enable audit log**   есть тестовая полиси . надо включить                                                                                                                                                                                   |
|:-------------------:|:----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 7%                                                                                                                                                                                                                                            |
|       Cluster       | cluster2 (`kubectl config use-context cluster2-admin@cluster2`)                                                                                                                                                                               |
| Acceptance criteria | - **logs** `/var/logs/kubernetes-api.log`<br/>- **policy** `/etc/kubernetes/policy/log-policy.yaml`<br/>- From `Secret` resources, level `Metadata`, namespace `prod`.<br/>- From `configmaps`, level `RequestResponse`, namespace `billing`. |
---

|     **4**     7     | **CIS Benchmark** надо найти по пределенной проблеме (не номеру а описанию ) и пофиксить                                                                                                                                                                                                                                                                                                                                                                                                   |
|:-------------------:|:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 3%                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                                                                                                                                                                                                                                                                                                                                                                                                                            |
| Acceptance criteria | - CIS Benchmark is installed on nodes<br/>- fix on `control-plane`:<br/>&nbsp;&nbsp;- `1.2.15` Ensure that the `--profiling` argument is set to false<br/>&nbsp;&nbsp;- `1.3.2` Ensure that the `--profiling` argument is set to false (Automated)<br/>&nbsp;&nbsp;- `1.4.1` Ensure that the `--profiling` argument is set to false (Automated)<br/><br/>- fix on `worker node`:<br/>&nbsp;&nbsp;- `4.2.6` Ensure that the `--protect-kernel-defaults` argument is set to true (Automated) |
---

|    **14**     11    | **Fix Dockerfile**   and deployment                                                                                                                                                                              |
|:-------------------:|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 4%                                                                                                                                                                                                               |
|       Cluster       | any                                                                                                                                                                                                              |
| Acceptance criteria | fix Dockerfile `/var/work/14/Dockerfile`:<br/>&nbsp;&nbsp;- use FROM image `20.04` version<br/>&nbsp;&nbsp;- use `myuser` for running app<br/>&nbsp;&nbsp;- build image `cks:14` (podman installed on worker pc) |
---


---




|        **9**        | **AppArmor**                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|     Task weight     | 3%                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
|       Cluster       | cluster6 (`kubectl config use-context cluster6-admin@cluster6`)                                                                                                                                                                                                                                                                                                                                                                                                     |
| Acceptance criteria | - install appArmor profile from `/opt/course/9/profile` (work pc) to `worker node` on cluster<br/>- Add label `security=apparmor` to the Node<br/>- Create a `Deployment` named `apparmor` in `apparmor` Namespace with:<br/>&nbsp;&nbsp;- image: `nginx:1.19.2`<br/>&nbsp;&nbsp;- container named `c1`<br/>&nbsp;&nbsp;- AppArmor profile enabled<br/>&nbsp;&nbsp;- nodeSelector to `workerNode`<br/>- save logs of the Pod into `/var/work/tests/artifacts/9/log` |

|       **11**        | **RBAC**                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| :-----------------: |:----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 6%                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
|       Cluster       | cluster6 (`kubectl config use-context cluster6-admin@cluster6`)                                                                                                                                                                                                                                                                                                                                                                                                                   |
| Acceptance criteria | - update existing permissions for SA `dev` in Namespaces `rbac-1`:<br/>&nbsp;&nbsp;- delete verb `delete` for pods<br/>&nbsp;&nbsp;- add verb `watch` for pods<br/>- create new role `dev` in `rbac-2` Namespaces:<br/>&nbsp;&nbsp;- resource configmaps, verbs = `get,list`<br/>- create rolebinding `dev` in `rbac-2`, sa = `dev` in `rbac-1` Namespace , role = `dev`  <br/>- create pod `dev-rbac NS=rbac-1` image = `viktoruj/cks-lab`, command = `sleep 60000`, SA=`dev`  ,`automountServiceAccountToken: true` |
---

|     **13**          | **Image policy webhook**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
|:-------------------:| :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|     Task weight     | 6%                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
|       Cluster       | cluster8 (`kubectl config use-context cluster8-admin@cluster8`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Acceptance criteria | **configure image policy webhook**:<br/>&nbsp;&nbsp;- `/etc/kubernetes/pki/admission_config.json`<br/>&nbsp;&nbsp;- `/etc/kubernetes/pki/webhook/admission_kube_config.yaml`<br/>&nbsp;&nbsp;- `https://image-bouncer-webhook:30020/image_policy`<br/>**create pod**  - `test-lasted` in `default` ns with image `nginx`<br/><br/>**result:** `Error from server (Forbidden): pods test is forbidden: image policy webhook .... latest tag are not allowed`<br/><br/>**create pod**  - `test-tag` in `default` ns with image `nginx:alpine3.17`<br/><br/>**result:** `ok` |
|                     |
---

|       **17**       | **Open Policy Agent - Blacklist Images from very-bad-registry.com**                                                                                                                                                                                                                         |
| :--------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|     Task weight        | 6%                                                                                                                                                                                                                           |
|       Cluster           | cluster9 (`kubectl config use-context cluster9-admin@cluster9`)                                                                                                                                                             |
| Acceptance criteria      | - Cannot run a pod with an image from **very-bad-registry.com**                                                                                                                                                               |
---
|       **18**       | **Create Pod with Seccomp Profile. profile is located on work node   /var/work/profile-nginx.json**                                                                              |
| :-----------------: |:-------------------------------------------------------------------------------------------------------------------|
|     **Task weight**     | 6%                                                                                                                 |
|       **Cluster**       | cluster10 (`kubectl config use-context cluster10-admin@cluster10`)                                                 |
| **Acceptance criteria** | - Pod status is Running<br/>- Pod name is seccomp<br/>- Image is nginx<br/>- Seccomp profile is profile-nginx.json |
---



