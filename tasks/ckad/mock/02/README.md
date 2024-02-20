# Allowed resources

## **Kubernetes Documentation:**

<https://kubernetes.io/docs/> and their subdomains

<https://kubernetes.io/blog/> and their subdomains

<https://helm.sh/> and their subdomains

This includes all available language translations of these pages (e.g. <https://kubernetes.io/zh/docs/>)

![preview](./preview.png)

- run ``time_left`` on work pc to **check time**
- run ``check_result`` on work pc to **check result**

## Questions

|        **1**        | Create a secret **secret1** with value **key1=value1** in the namespace **jellyfish**. Add that secret as an environment variable to an existing **pod1** in the same namespace. |
| :-----------------: |:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                                                                                                               |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                  |
| Acceptance criteria | - Name: `secret1` <br/>- key1: `value1`<br/>- Namespace: `jellyfish`                                                                                                             |

|        **2**        | Create a cron job `cron-job1`                                                                                                                                                                                                                        |
|:-------------------:|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                                                                                                                                                                                   |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                      |
| Acceptance criteria | - name: `cron-job1` <br/>- namespace: `rnd`  <br/>- image: `viktoruj/cks-lab` <br/>-  imagePullPolicy: `IfNotPresent` <br/>-  command: `echo "Hello from CKAD mock"` <br/>- tolerate 4 failures <br/>-  complet 3 times <br/>-  run every 15 minutes |

|        **3**        | There is deployment `my-deployment` in the namespace `baracuda` . Update deployment                                                  |
| :-----------------: |:-------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                                                                   |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                      |
| Acceptance criteria | - Scale deployment to 5 replicas  <br/>- Update image nginx:1.24.0-alpine-slim for container web-srv <br/>- Rollback deployment to the previous version |

|        **4**        | Create deployment  `shark-app` in the `shark` namespace.                                                                                                  |
| :-----------------: |:----------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                                                                                        |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                           |
| Acceptance criteria | - Name: `shark-app` <br/>- namespace `shark`  <br/>- Image: `viktoruj/ping_pong`<br/>- container port `8080` <br/>- Environment variable `ENV1` = `8080`  |

|        **5**        | Build container image using given `/path/to/Dockerfile`. Podman is instaled on Worker-PC              |
| :-----------------: |:------------------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                       |
| Acceptance criteria | - Image Name: `my-image` <br/>- Tag: `0.0.1`<br/>- export image in OCI format to `/var/work/my-image.tar` |

|        **6**        | Update `sword-app` deployment in the `swordfish` namespace                         |
| :-----------------: |:-----------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                 |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                    |
| Acceptance criteria | - user with ID `5000`  <br/>- restrict privilege execution |

|        **7**        | There are deployment, service and the ingress  in  `meg` namespace . user can't access to the app `http://ckad.local:30200/app` . Plese fix it . |
| :-----------------: |:-------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 1%      - Ingress has wrong svc name, app path was wrong  , - Svc has wrong app port                                                             |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                  |
| Acceptance criteria | - ` curl http://ckad.local:30200/app ` works.                                                                                                    |

|        **8**        | There is a pod web-app in namespace tuna. Web-app should be able to communicate to pod with label type=db and pod label type=backend.Network policies have already been created, don't modify them |
| :-----------------: |:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                                                                                                                                 |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                    |
| Acceptance criteria | - pods  can communicate                                                                                                                                                                            |

|        **9**        | Deployment main-app in a salmon namespace, has 3 replicas. It is published via main-app-svc service. Create canary deployment canary-app similar to main-app deployment. main-app deployment file is here: /path/to/deployment.yaml.Make sure that deployment is receiving 20% of the traffic. Keep in mind that salmon namespace only allows 8 pod running. |
| :-----------------: |:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                                                                                                                                                                                                                                                                                           |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                                                                                              |
| Acceptance criteria |                                                                                                                                                                                                                                                                               |



---
|        **3**        | **Create secret from file .  create doployment  , mount the secret as a file **                                                                                                                              |
| :-----------------: |:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 4%                                                                                                                                                                                                           |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                              |
| Acceptance criteria | - secret: ns=`dev-db` name=`dbpassword` key=`pwd` value=`my-secret-pwd`  <br/>- pod: ns=`dev-db` name=`db-pod` image=`mysql:8.0` env.name=`MYSQL_ROOT_PASSWORD` env.value=from secret `dbpassword` key=`pwd` |
---
---
|        **8**        | **Export the logs of the pod `app-xyz3322` to a file located at `/opt/logs/app-xyz123.log`. The pod is located in a different namespace. First, identify the namespace where the pod is running.** |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 1%                                                                                                                                                                                                 |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                    |
| Acceptance criteria | - Logs at `/opt/logs/app-xyz123.log`                                                                                                                                                               |
---
|       **12**        | **Create a new pod called `nginx1233` in the `web-ns` namespace with the image `nginx`. Add a livenessProbe to the container to restart it if the command `ls /var/www/html/` probe fails. This check should start after a delay of 10 seconds and run every 60 seconds.** |
| :-----------------: |:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 2%                                                                                                                                                                                                                                                                         |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                            |
| Acceptance criteria | - You may delete and recreate the object. Ignore the warnings from the probe.<br/>- Pod: `nginx1233`, namespace: `web-ns`, image `nginx`,  livenessProbe?                                                                                                                  |

---
|       **18**        | **Add prometheus helm repo and install prometheus chart to the cluster.**                                                                                                                                                                                                        |
| :-----------------: |:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 4%                                                                                                                                                                                                                                                                               |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                  |
| Acceptance criteria | - Add repo `prometheus-community` `https://prometheus-community.github.io/helm-charts`<br/>- Install prometheus from the helm chart to kubernetes cluster<br/>    - Release name: `prom`, namespace: `monitoring`<br/>- helm chart: `prometheus-community/kube-prometheus-stack` |
---
