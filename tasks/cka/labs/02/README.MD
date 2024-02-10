We have an enterprise application in namespace  **prod-jobs**.
The application fetches tasks for processing from a queue (Kafka).
We need to create **Horizontal Pod Autoscaling** based on **CPU** load.
When the CPU load rises to **100%** we need to increase the number of pods to **6**.
The **minimum** amount of pods should be **2**.
