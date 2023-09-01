## Question 8 | Secure Kubernetes Dashboard

#### Task weight: 3%





The Kubernetes Dashboard is installed in Namespace kubernetes-dashboard-head and is configured to:

* Allow users to "skip login"
* Allow insecure access (HTTP without authentication)
* Allow basic authentication
* Allow access from outside the cluster


You are asked to make it more secure by:

* Deny users to "skip login"
* Deny insecure access, enforce HTTPS (self signed certificates are ok for now)
* Add the --auto-generate-certificates argument
* Enforce authentication using a token (with possibility to use RBAC)
* Allow only cluster internal access
