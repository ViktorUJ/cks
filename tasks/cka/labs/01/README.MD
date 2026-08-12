## Fix problems with kube-api.

There are problems with the k8s cluster.

Connect to the control plane node using `ssh k8s1_controlPlane_1` and fix them.

Then return and deploy a pod named `webhttpd` in the `apx-z993845` namespace using the `httpd:alpine` image.
