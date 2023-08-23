##CIS Benchmark
Task weight: 3%

You're ask to evaluate specific settings of cluster against the CIS Benchmark recommendations. Use the tool kube-bench which is already
installed on the nodes.
Connect using ssh master and ssh worker1 .
On the master node ensure (correct if necessary) that the CIS recommendations are set for:
1. The --profiling argument of the kube-controller-manager
2. The ownership of directory /var/lib/etcd
On the worker node ensure (correct if necessary) that the CIS recommendations are set for:
3. The permissions of the kubelet configuration /var/lib/kubelet/config.yaml
4. The --client-ca-file argument of the kubelet
