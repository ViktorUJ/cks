Task weight: 3%

Some containers need to run more secure and restricted.
There is an existing AppArmor profile located at /opt/course/9/profile on worker node .

Install the AppArmor profile on Node node1. Connect using ssh cluster1-node1.

Add label security=apparmor to the Node

Create a Deployment named apparmor in Namespace default with:

One replica of image nginx:1.19.2
NodeSelector for security=apparmor
Single container named c1 with the AppArmor profile enabled
The Pod might not run properly with the profile enabled. Write the logs of the Pod into /opt/course/9/logs so another team can work on getting the application running.
