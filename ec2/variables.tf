variable "project_name" {
  type        = string
  description = "Project name"
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC where EC2 instances will be launched"
}

variable "subnets_id" {
  type = object({
    public_subnets  = list(string)
    private_subnets = list(string)
  })
  description = "Object containing lists of public and private subnet IDs"
}

variable "subnets_cidr" {
  type = object({
    public_subnets  = list(string)
    private_subnets = list(string)
  })
  description = "Object containing lists of public and private subnet CIDR blocks"
}

variable "keypair_name" {
  type = string
  description = "Name of the keypair to use for EC2 instances"
}

variable "instance_image" {
  type = object({
    owners = list(string)
    values = list(string)
  })
  description = "Instance image object details"
}

variable "instance_type" {
  type = string
  description = "Name of the keypair to use for EC2 instances"
}