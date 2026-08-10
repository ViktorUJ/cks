variable "region" {}
variable "aws" {}
variable "prefix" {}
variable "USER_ID" {
  type    = string
  default = "defaultUser"
}
variable "ENV_ID" {
  type    = string
  default = "defaultId"
}
variable "app_name" {}

variable "STACK_NAME" {
  type    = string
  default = ""
}

variable "STACK_TASK" {
  type    = string
  default = ""
}
variable "name" {
  type = string
}

variable "nodepool" {
  type = object({
    limits      = optional(map(string), { cpu = 100 })
    expireAfter = optional(string, "720h")
  })
}
variable "disruption" {
  type = object({
    consolidationPolicy = optional(string, "WhenEmptyOrUnderutilized")
    consolidateAfter    = optional(string, "600s")
  })
}

variable "budgets" {
  type = list(object({
    nodes    = string
    schedule = optional(string)
    duration = optional(string)
    reasons  = optional(list(string))
  }))
  default = [
    { nodes = "10%" }
  ]
}

variable "taints" {
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}

variable "requirements" {
  type = list(object({
    key      = string
    operator = string
    values   = list(string)
  }))

}
variable "vng" {
  type = object({
    name      = string
    labels    = optional(map(string), {})
    iam_role  = string
    ami_alias = optional(string, "al2023@latest")
    tags      = map(string)
    blockDeviceMappings = optional(list(object({
      deviceName = optional(string, "/dev/xvda")
      ebs = object({
        volumeSize          = optional(string, "20Gi")
        volumeType          = optional(string, "gp3")
        deleteOnTermination = optional(bool, true)
        encrypted           = optional(bool, true)
        iops                = optional(number, 3000)
        throughput          = optional(number, 125)
      })
    })))
    # IMDS hardening for EC2NodeClass (Karpenter). Leave null to omit the field
    # entirely and keep provider defaults (httpTokens=optional, hop limit unset).
    metadataOptions = optional(object({
      httpEndpoint            = optional(string, "enabled")
      httpProtocolIPv6        = optional(string, "disabled")
      httpPutResponseHopLimit = optional(number, 2)
      httpTokens              = optional(string, "required")
    }), null)

  })

}
