Task weight: 7%
Use context: kubectl config use-context workload-prod

There is a Deployment image-verify in Namespace team-blue which runs image registry.killer.sh:5000/image-verify:v1. DevSecOps has asked you to improve this image by:

Changing the base image to alpine:3.12
Not installing curl
Updating nginx to use the version constraint >=1.18.0
Running the main process as user myuser

prevent escalation
read only root filesystem
none root user  (security context)
set user id and grout id to pod

delete ( sh)
