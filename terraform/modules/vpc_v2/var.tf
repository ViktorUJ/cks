variable "region" {}
variable "vpc_default_cidr" {}

variable "aws" {}
variable "prefix" {}
variable "app_name" {}
variable "USER_ID" {
  type    = string
  default = "defaultUser"
}
variable "ENV_ID" {
  type    = string
  default = "defaultId"
}

variable "STACK_NAME" {
  type    = string
  default = ""
}

variable "STACK_TASK" {
  type    = string
  default = ""
}
variable "tags_common" {
  type = map(string)
}

variable "subnets" {
  type = object({
    public = optional(map(object({
      name = string
      cidr = string
      az   = string # Availability Zone or Availability Zone ID
      tags = optional(map(string), {})
      type = optional(string, "public") # any sort key for grouping . example , DB , WEB , APP , etc

      assign_ipv6_address_on_creation                = optional(bool, false)
      customer_owned_ipv4_pool                       = optional(string, "")
      enable_dns64                                   = optional(bool, false)
      enable_resource_name_dns_aaaa_record_on_launch = optional(bool, false)
      enable_resource_name_dns_a_record_on_launch    = optional(bool, false)
      ipv6_cidr_block                                = optional(string, "")
      ipv6_native                                    = optional(bool, false)
      map_customer_owned_ip_on_launch                = optional(bool, false)
      map_public_ip_on_launch                        = optional(bool, true)
      outpost_arn                                    = optional(string, "")
      private_dns_hostname_type_on_launch            = optional(string, "ip-name")
      #  The type of hostnames to assign to instances in the subnet at launch. For IPv6-only subnets, an instance DNS name must be based on the instance ID. For dual-stack and IPv4-only subnets, you can specify whether DNS names use the instance IPv4 address or the instance ID . Valid values:  ip-name, resource-name.
      nacl = optional(map(object({
        egress      = string # true, false
        rule_number = string # ACL entries are processed in ascending order by rule number
        rule_action = string # allow | deny
        from_port   = optional(string, "")
        to_port     = optional(string, "")
        icmp_code   = optional(string, "")
        # (Optional) ICMP protocol: The ICMP type. Required if specifying ICMP for the protocolE.g., -1
        icmp_type = optional(string, "")
        # (Optional) ICMP protocol: The ICMP code. Required if specifying ICMP for the protocolE.g., -1
        protocol   = string # A value of -1 means all protocols , tcp  - 6 ,
        cidr_block = optional(string, "")
        # The network range to allow or deny, in CIDR notation (for example 172.16.0.0/24 ).
        ipv6_cidr_block = optional(string, "")

      })), {})

    })))
    private = optional(map(object({
      name        = string
      cidr        = string
      az          = string # Availability Zone or Availability Zone ID
      tags        = optional(map(string), {})
      type        = optional(string, "private") # any sort key for grouping . example , DB , WEB , APP , etc
      nat_gateway = optional(string, "AZ")
      # AZ - nat gateway for  each AZ , SINGLE - single nat gateway for all AZ , DEFAULT - default nat gateway for all AZ  with SINGLE value ,SUBNET - dedicate nat gateway for each  subnet with SUBNET  type   ,  NONE - no nat gateway
      assign_ipv6_address_on_creation                = optional(bool, false)
      customer_owned_ipv4_pool                       = optional(string, "")
      enable_dns64                                   = optional(bool, false)
      enable_resource_name_dns_aaaa_record_on_launch = optional(bool, false)
      enable_resource_name_dns_a_record_on_launch    = optional(bool, false)
      ipv6_cidr_block                                = optional(string, "")
      ipv6_native                                    = optional(bool, false)
      map_customer_owned_ip_on_launch                = optional(bool, false)
      map_public_ip_on_launch                        = optional(bool, true)
      outpost_arn                                    = optional(string, "")
      private_dns_hostname_type_on_launch            = optional(string, "ip-name")
      #  The type of hostnames to assign to instances in the subnet at launch. For IPv6-only subnets, an instance DNS name must be based on the instance ID. For dual-stack and IPv4-only subnets, you can specify whether DNS names use the instance IPv4 address or the instance ID . Valid values:  ip-name, resource-name.
      nacl = optional(map(object({
        egress      = string # true, false
        rule_number = string # ACL entries are processed in ascending order by rule number
        rule_action = string # allow | deny
        from_port   = optional(string, "")
        to_port     = optional(string, "")
        icmp_code   = optional(string, "")
        # (Optional) ICMP protocol: The ICMP type. Required if specifying ICMP for the protocolE.g., -1
        icmp_type = optional(string, "")
        # (Optional) ICMP protocol: The ICMP code. Required if specifying ICMP for the protocolE.g., -1
        protocol   = string # A value of -1 means all protocols , tcp  - 6 ,
        cidr_block = optional(string, "")
        # The network range to allow or deny, in CIDR notation (for example 172.16.0.0/24 ).
        ipv6_cidr_block = optional(string, "")

      })), {})

    })))
  })
  default = {
    public  = {}
    private = {}
  }
}
