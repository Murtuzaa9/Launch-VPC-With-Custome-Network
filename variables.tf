variable "availabilityZone" {
  default = "us-east-1a"
}
variable "instanceTenancy" {
  default = "default"
}
variable "dnsSupport" {
  default = true
}
variable "dnsHostNames" {
  default = true
}
variable "vpcCIDRblock" {
  default = "10.0.0.0/16"
}
variable "subnetCIDRblock" {
  default = "10.0.1.0/24"
}
variable "destinationCIDRblock" {
  default = "0.0.0.0/0"
}
variable "ingressCIDRblock" {
  type    = list
  default = ["0.0.0.0/0"]
}
variable "egressCIDRblock" {
  type    = list
  default = ["0.0.0.0/0"]
}
variable "mapPublicIP" {
  default = true
}
# end of variables.tf
variable "instance_ami" {
  description = "AMI for aws EC2 instance"
  default     = "ami-098f16afa9edf40be"
}
variable "instance_type" {
  description = "type for aws EC2 instance"
  default     = "t2.small"
}
variable "users" {
  default = "ec2-user"
}
