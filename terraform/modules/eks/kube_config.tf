locals {
  config_map_aws_auth = <<CONFIGMAPAWSAUTH

apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.eks-node.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: ${aws_iam_role.eks_admin.arn}
      groups:
        - system:masters

CONFIGMAPAWSAUTH
}

resource "local_file" "config_map_aws_auth" {
  content  = local.config_map_aws_auth
  filename = "${var.prefix}_${var.aws}config_map_aws_auth.yaml"
}
resource "local_file" "kubeconfig" {
  content  = local.kubeconfig
  filename = "k8-config"
  lifecycle {
    ignore_changes = [content]
  }
}


resource "null_resource" "cube_config" {
  depends_on = [
    local_file.config_map_aws_auth,
    local_file.kubeconfig,
    aws_eks_node_group.common,
    aws_eks_cluster.eks-cluster
  ]
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    when        = create
    command     = <<EOF
    echo "*** wait ready eks"
    echo "*****   ${local_file.kubeconfig.filename}"
    check_node=$(kubectl get ns --kubeconfig=${local_file.kubeconfig.filename}| grep kube)
    declare -i timeout_max=300
    declare -i timeout=0
    while [[ -z "$check_node" && $timeout -lt $timeout_max ]]; do
      sleep 2; timeout+=2 ; echo "*** wait eks node  2 sek ($timeout) of $timeout_max"
      check_node=$(kubectl get ns --kubeconfig=${local_file.kubeconfig.filename} | grep kube)
     done
    if [[ "$timeout" -lt "$timeout_max" ]] ; then
       echo " node timeout : $timeout "
      else
       echo "error timeout node  $timeout"
       exit 1
    fi
kubectl apply -f ${local_file.config_map_aws_auth.filename} --kubeconfig=${local_file.kubeconfig.filename} ; kubectl get namespaces --kubeconfig=${local_file.kubeconfig.filename}
EOF

  }
}


