# Nginx ingress. Routing 30% of requests to new version of app.

We use the **ingress nginx** controller.
We have an  application (deployment, service , ingress) in namespace  **meg**. You can check the app via command  `curl http://ckad.local:30102/app`

You need create new deployment, service, ingress  in namespace  **meg**
 - **deployment** : name ` meg-app2` , env:  name: `SERVER_NAME` and  value: `megApp2` , all other parameters  copy from  `meg-app` deployment
 - **service**    : name ` meg-app2`   -> deployment ` meg-app2`
 - **ingress**    : name ` meg-app2`   -> service ` meg-app2`  , route 30% of requests to new version of app .

In case of any other header value or unset header, the request should go to the old service.

Run the command 10 times to test it `    curl  http://ckad.local:30102/app    `
You are expected to see a response from **megApp2** of about **30%**.


check result via  tests
```
check_result

```
````
ubuntu@worker:~> check_result
 ✓ 0  Init
 ✓ 1.1 Check routing to version 2
 ✓ 1.2 Check ingress v2 canary-weight

3 tests, 0 failures
 result = 100.00 %   ok_points=2  all_points=2
time_left=333 minutes
you  spend 26 minutes

````
