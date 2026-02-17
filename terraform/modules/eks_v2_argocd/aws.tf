provider "aws" {
  region  = var.region
  profile = var.aws
}
provider "aws" {
  alias  = "cmdb"
  region = var.region_cmdb
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}