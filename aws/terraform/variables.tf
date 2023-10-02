variable "project_prefix" {
  description = "projectPrefix name for tagging"
  default     = "f5-bigip"
}

variable "resource_owner" {
  description = "Owner of the deployment for tagging purposes"
  default     = "bigip-team"
}

variable "aws_region" {
  description = "aws region"
  type        = string
  default     = "us-east-2"
}

variable "aws_az1" {
  description = "Availability zone, will dynamically choose one if left empty"
  type        = string
  default     = null
}

variable "aws_az2" {
  description = "Availability zone, will dynamically choose one if left empty"
  type        = string
  default     = null
}

variable "bigip_admin_password" {
  description = "BIG-IP Admin Password (set on first boot)"
  default = "F5P@ssw0rd!"
  type = string
  sensitive = true
}

variable "lab_domain" {
  description = "domain name for lab hostnames"
  default = "mylab.local"
  type = string
}

variable "bigip_license_az1" {
  description = "BIG-IP License for AZ1 instance"
  type = string
  default = "PAYG"
}

variable "bigip_license_az2" {
  description = "BIG-IP License for AZ2 instance"
  type = string
  default = "PAYG"
}

variable "vpc_ipv4_cidr" {
  description = "IPv4 Subnet for VPC in CIDR format"
  type = string
  default = "10.255.0.0/16"
}

variable "client_ec2_instance" {
  description = "EC2 instance type for Juice Shop servers"
  default = "t3.nano"
}

variable "server_ec2_instance" {
  description = "EC2 instance type for Juice Shop servers"
  default = "t3.nano"
}

variable get_address_url_ipv4 {
  description = "URL for retrieving my external IPv4 address"
  type = string
  default = "https://api.ipify.org"
}

variable get_address_url_ipv6 {
  description = "URL for retrieving my external IPv6 address"
  type = string
  default = "https://api6.ipify.org"
}

variable get_address_request_headers {
  description = "HTTP headers to send"
  type = map
  default = {
    Accept = "text/plain"
  }
}

variable "bigip_license_type" {
  description = "license type BYOL or PAYG"
  type = string
  default = "PAYG"
}

variable "bigip_ami_mapping" {
  description = "mapping AMIs for PAYG and BYOL"
  type = map(string)
  default = {
    "BYOL" = "All Modules 2Boot Loc"
    "PAYG" = "Best 10Gbps"
  }
}

variable "bigip_ec2_instance_type" {
  description = "instance type for the BIG-IP instances"
  default = "t2.medium"
}

variable "bigip_version" {
  description = "the base TMOS version to use - most recent version will be used"
  type = string
  default =  "17.1"
}

variable "f5_do_version" {
  description = "f5 declarative onboarding version (see https://github.com/F5Networks/f5-declarative-onboarding/releases/latest)"
  type = string
  default = "1.39.0"
}

variable "f5_do_schema_version" {
  description = "f5 declarative onboarding version (see https://github.com/F5Networks/f5-declarative-onboarding/releases/latest)"
  type = string
  default = "1.39.0"
}

variable "f5_as3_version" {
  description = "f5 application services version (see https://github.com/F5Networks/f5-appsvcs-extension/releases/latest)"
  type = string
  default = "3.46.0"
}

variable "f5_as3_schema_version" {
  description = "f5 application services version (see https://github.com/F5Networks/f5-appsvcs-extension/releases/latest)"
  type = string
  default = "3.46.0"
}

variable "f5_ts_version" {
  description = "f5 telemetry streaming version (see https://github.com/F5Networks/f5-declarative-onboarding/releases/latest)"
  type = string
  default = "1.33.0"
}

variable "f5_ts_schema_version" {
  description = "f5 telemetry streaming version (see https://github.com/F5Networks/f5-declarative-onboarding/releases/latest)"
  type = string
  default = "1.33.0"
}

variable "f5_cf_version" {
  description = "f5 cloud failover extension version (see https://github.com/F5Networks/f5-cloud-failover-extension/releases/)"
  type = string
  default = "1.15.0"
}

variable "f5_cf_schema_version" {
  description = "f5 cloud failover extension version (see https://github.com/F5Networks/f5-cloud-failover-extension/releases/)"
  type = string
  default = "1.15.0"
}