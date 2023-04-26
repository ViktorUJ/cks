## Question 15 | Configure TLS on Ingress
#### Task weight: 4%

 

Use context: `kubectl config use-context workload-prod`

 

In Namespace `team-pink` there is an existing Nginx Ingress resources named `secure` which accepts two paths `/app` and `/api` which point to different ClusterIP Services.

From your main terminal you can connect to it using for example:

* HTTP: `curl -v http://secure-ingress.test:31080/app`
* HTTPS: `curl -kv https://secure-ingress.test:31443/app`

Right now it uses a default generated TLS certificate by the Nginx Ingress Controller.

You're asked to instead use the key and certificate provided at `/opt/course/15/tls.key` and `/opt/course/15/tls.crt`. As it's a self-signed certificate you need to use `curl -k` when connecting to it.
