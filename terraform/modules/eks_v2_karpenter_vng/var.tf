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

variable "vng" {
  type = object({
    name      = string
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

    nodepool = optional(object({
      limits = optional(map(string), { cpu = 100 })

      disruption = optional(object({
        consolidationPolicy = optional(string, "WhenEmptyOrUnderutilized")
        consolidateAfter    = optional(string, "600s")
        budgets             = optional(list(map(string)), [{ nodes = "30%" }])
      }))

      expireAfter = optional(string, "720h")
      requirements = list(object({
        key      = string
        operator = string
        values   = list(string)
      }))
    }))
  })

}
