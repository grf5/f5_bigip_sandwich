##
## General Environment Setup
##
data "aws_availability_zones" "available" {
  state = "available"
}

resource "tls_private_key" "newkey" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "local_sensitive_file" "newkey_pem" { 
  # create a new local ssh identity
  filename = "${abspath(path.root)}/.ssh/${var.project_prefix}-key-${random_id.build_suffix.hex}.pem"
  content = tls_private_key.newkey.private_key_pem
  file_permission = "0400"
}

resource "aws_key_pair" "deployer" {
  # create a new AWS ssh identity
  key_name = "${var.project_prefix}-key-${random_id.build_suffix.hex}"
  public_key = tls_private_key.newkey.public_key_openssh
}

data "http" "ipv4_address" {
  # retrieve the local public IP address
  url = var.get_address_url_ipv4
  request_headers = var.get_address_request_headers
}

# data "http" "ipv6_address" {
#   # retrieve the local public IPv6 address
#   url = var.get_address_url_ipv6
#   request_headers = var.get_address_request_headers
# }

data "aws_caller_identity" "current" {
  # Get the current AWS caller identity
}

##
## Locals
##

locals {
  aws_az1 = var.aws_az1 != null ? var.aws_az1 : data.aws_availability_zones.available.names[0]
  aws_az2 = var.aws_az2 != null ? var.aws_az1 : data.aws_availability_zones.available.names[1]
}

##
## Juice Shop VM AMI - Ubuntu
##

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

##
## BIG-IP AMI - F5
##

data "aws_ami" "F5BIG-IP_AMI" {

  most_recent = true

  filter {
    name = "name"
    values = ["F5 BIGIP-${var.bigip_version}*${lookup(var.bigip_ami_mapping, var.bigip_license_type)}*"]
  }

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["self","679593333241"]

}

##########################
## F5 BIG-IP HA Cluster ##
##########################

##
## VPC
##

resource "aws_vpc" "bigip_sandwich" {

  cidr_block = var.vpc_ipv4_cidr
  assign_generated_ipv6_cidr_block = true

  enable_dns_hostnames= false
  enable_dns_support = true  

  tags = {
    Name = "${var.project_prefix}-bigip-sandwich-${random_id.build_suffix.hex}"
  }

}

resource "aws_default_security_group" "bigip" {

  vpc_id = aws_vpc.bigip_sandwich.id

  ingress {
    description = "Permit traffic from the same security-group members"
    protocol = -1
    self = true
    from_port = 0
    to_port = 0
  }
  ingress {
    description = "permit IPv4 mgmt traffic from ${var.resource_owner}"
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_blocks = [format("%s/%s",data.http.ipv4_address.response_body,32)]
  }
  # ingress {
  #   description = "permit IPv6 mgmt traffic from ${var.resource_owner}"
  #   protocol = "-1"
  #   from_port = 0
  #   to_port = 0
  #   ipv6_cidr_blocks = [format("%s/%s",data.http.ipv6_address.response_body,128)]
  # }
  dynamic ingress {
    for_each = var.additional_management_ipv4_cidr_blocks
    content{
      description = "permit IPv4 mgmt traffic from ${ingress.value}"
      protocol = "-1"
      from_port = 0
      to_port = 0
      cidr_blocks = [ ingress.value ]
    }
  }
  dynamic ingress {
    for_each = var.additional_management_ipv6_cidr_blocks
    content{
      description = "permit IPv6 mgmt traffic from ${ingress.value}"
      protocol = "-1"
      from_port = 0
      to_port = 0
      cidr_blocks = [ ingress.value ]
    }
  }
  egress {
    description = "allow all IPv4 outbound"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "allow all IPv6 outbound"
    from_port = 0
    to_port = 0
    protocol = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.project_prefix}-bigip-sandwich-${random_id.build_suffix.hex}"
  }

}

resource "aws_subnet" "management_az1" {
  vpc_id = aws_vpc.bigip_sandwich.id
  cidr_block = cidrsubnet(var.vpc_ipv4_cidr,8,10)
  availability_zone = local.aws_az1
  ipv6_cidr_block = "${cidrsubnet(aws_vpc.bigip_sandwich.ipv6_cidr_block, 8, 10)}"
  assign_ipv6_address_on_creation = true
  tags = {
    Name = "${var.project_prefix}-management-az1-${random_id.build_suffix.hex}"
  }
}

resource "aws_subnet" "management_az2" {
  vpc_id = aws_vpc.bigip_sandwich.id
  cidr_block = cidrsubnet(var.vpc_ipv4_cidr,8,20)
  availability_zone = local.aws_az2
  ipv6_cidr_block = "${cidrsubnet(aws_vpc.bigip_sandwich.ipv6_cidr_block, 8, 20)}"
  assign_ipv6_address_on_creation = true
  tags = {
    Name = "${var.project_prefix}-management-az2-${random_id.build_suffix.hex}"
  }
}

resource "aws_subnet" "client_az1" {
  vpc_id = aws_vpc.bigip_sandwich.id
  cidr_block = cidrsubnet(var.vpc_ipv4_cidr,8,11)
  availability_zone = local.aws_az1
  ipv6_cidr_block = "${cidrsubnet(aws_vpc.bigip_sandwich.ipv6_cidr_block, 8, 11)}"
  assign_ipv6_address_on_creation = true
  tags = {
    Name = "${var.project_prefix}-client-az1-${random_id.build_suffix.hex}"
  }
}

resource "aws_subnet" "client_az2" {
  vpc_id = aws_vpc.bigip_sandwich.id
  cidr_block = cidrsubnet(var.vpc_ipv4_cidr,8,21)
  availability_zone = local.aws_az2
  ipv6_cidr_block = "${cidrsubnet(aws_vpc.bigip_sandwich.ipv6_cidr_block, 8, 21)}"
  assign_ipv6_address_on_creation = true
  tags = {
    Name = "${var.project_prefix}-client-az2-${random_id.build_suffix.hex}"
  }
}

resource "aws_subnet" "server_az1" {
  vpc_id = aws_vpc.bigip_sandwich.id
  cidr_block = cidrsubnet(var.vpc_ipv4_cidr,8,12)
  availability_zone = local.aws_az1
  ipv6_cidr_block = "${cidrsubnet(aws_vpc.bigip_sandwich.ipv6_cidr_block, 8, 12)}"
  assign_ipv6_address_on_creation = true
  tags = {
    Name = "${var.project_prefix}-server-az1-${random_id.build_suffix.hex}"
  }
}

resource "aws_subnet" "server_az2" {
  vpc_id = aws_vpc.bigip_sandwich.id
  cidr_block = cidrsubnet(var.vpc_ipv4_cidr,8,22)
  availability_zone = local.aws_az2
  ipv6_cidr_block = "${cidrsubnet(aws_vpc.bigip_sandwich.ipv6_cidr_block, 8, 22)}"
  assign_ipv6_address_on_creation = true
  tags = {
    Name = "${var.project_prefix}-server-az2-${random_id.build_suffix.hex}"
  }  
}

resource "aws_subnet" "security_zone_az1" {
  vpc_id = aws_vpc.bigip_sandwich.id
  cidr_block = cidrsubnet(var.vpc_ipv4_cidr,8,13)
  availability_zone = local.aws_az1
  ipv6_cidr_block = "${cidrsubnet(aws_vpc.bigip_sandwich.ipv6_cidr_block, 8, 13)}"
  assign_ipv6_address_on_creation = true
  tags = {
    Name = "${var.project_prefix}-security-zone-az1-${random_id.build_suffix.hex}"
  }
}

resource "aws_subnet" "security_zone_az2" {
  vpc_id = aws_vpc.bigip_sandwich.id
  cidr_block = cidrsubnet(var.vpc_ipv4_cidr,8,23)
  availability_zone = local.aws_az2
  ipv6_cidr_block = "${cidrsubnet(aws_vpc.bigip_sandwich.ipv6_cidr_block, 8, 23)}"
  assign_ipv6_address_on_creation = true
  tags = {
    Name = "${var.project_prefix}-security-zone-az2-${random_id.build_suffix.hex}"
  }  
}
resource "aws_internet_gateway" "bigip_sandwich" {
  vpc_id = aws_vpc.bigip_sandwich.id
  tags = {
    Name = "${var.project_prefix}-bigip-sandwich-${random_id.build_suffix.hex}"
  }
}

resource "aws_default_route_table" "bigip_sandwich" {
  default_route_table_id = aws_vpc.bigip_sandwich.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bigip_sandwich.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.bigip_sandwich.id
  }
  tags = {
    Name = "${var.project_prefix}-bigip-sandwich-${random_id.build_suffix.hex}"
  }
}

resource "aws_route_table" "client_routes_az1" {

  vpc_id = aws_vpc.bigip_sandwich.id

  route {
    cidr_block = aws_subnet.server_az1.cidr_block
    network_interface_id = aws_network_interface.bigip_az1_client.id
  }

  route {
    ipv6_cidr_block = aws_subnet.client_az1.ipv6_cidr_block
    network_interface_id = aws_network_interface.bigip_az1_client.id
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bigip_sandwich.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.bigip_sandwich.id
  }

  tags = {
    Name = "${var.project_prefix}-client-routes-az1-${random_id.build_suffix.hex}"
  }

}

resource "aws_route_table" "server_routes_az1" {

  vpc_id = aws_vpc.bigip_sandwich.id

  route {
    cidr_block = aws_subnet.client_az1.cidr_block
    network_interface_id = aws_network_interface.bigip_az1_server.id
  }

  route {
    ipv6_cidr_block = aws_subnet.client_az1.ipv6_cidr_block
    network_interface_id = aws_network_interface.bigip_az1_server.id
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bigip_sandwich.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.bigip_sandwich.id
  }

  tags = {
    Name = "${var.project_prefix}-server-routes-az1-${random_id.build_suffix.hex}"
  }

}

resource "aws_route_table" "client_routes_az2" {

  vpc_id = aws_vpc.bigip_sandwich.id

  route {
    cidr_block = aws_subnet.server_az2.cidr_block
    network_interface_id = aws_network_interface.bigip_az2_client.id
  }

  route {
    ipv6_cidr_block = aws_subnet.server_az2.ipv6_cidr_block
    network_interface_id = aws_network_interface.bigip_az2_client.id
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bigip_sandwich.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.bigip_sandwich.id
  }

  tags = {
    Name = "${var.project_prefix}-client-routes-az2-${random_id.build_suffix.hex}"
  }

}

resource "aws_route_table" "server_routes_az2" {

  vpc_id = aws_vpc.bigip_sandwich.id

  route {
    cidr_block = aws_subnet.client_az2.cidr_block
    network_interface_id = aws_network_interface.bigip_az2_client.id
  }

  route {
    ipv6_cidr_block = aws_subnet.client_az2.ipv6_cidr_block
    network_interface_id = aws_network_interface.bigip_az2_server.id
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bigip_sandwich.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.bigip_sandwich.id
  }

  tags = {
    Name = "${var.project_prefix}-server-routes-az2-${random_id.build_suffix.hex}"
  }

}

resource "aws_route_table_association" "client-az1" {
  subnet_id = aws_subnet.client_az1.id
  route_table_id = aws_route_table.client_routes_az1.id
}

resource "aws_route_table_association" "server-az1" {

  subnet_id = aws_subnet.server_az1.id
  route_table_id = aws_route_table.server_routes_az1.id

}

resource "aws_route_table_association" "client-az2" {

  subnet_id = aws_subnet.client_az2.id
  route_table_id = aws_route_table.client_routes_az2.id

}

resource "aws_route_table_association" "server-az2" {

  subnet_id = aws_subnet.server_az2.id
  route_table_id = aws_route_table.server_routes_az2.id

}

## 
## BIG-IP AMI/Onboarding Config
##

##
## AZ1 F5 BIG-IP
##

resource "aws_network_interface" "bigip_az1_mgmt" {
  subnet_id = aws_subnet.management_az1.id
  # Disable IPV6 dual stack management because it breaks DO clustering
  ipv6_address_count = 0
  tags = {
    Name = "${var.project_prefix}-bigip-az1-mgmt-${random_id.build_suffix.hex}"
  }
}

resource "aws_network_interface" "bigip_az1_client" {
  source_dest_check = false
  subnet_id = aws_subnet.client_az1.id
  tags = {
    Name = "${var.project_prefix}-bigip-az1-client-${random_id.build_suffix.hex}"
  }
}

resource "aws_network_interface" "bigip_az1_server" {
  source_dest_check = false
  subnet_id = aws_subnet.server_az1.id
  tags = {
    Name = "${var.project_prefix}-bigip-az1-server-${random_id.build_suffix.hex}"
  }
}

resource "aws_network_interface" "bigip_az1_security_zone" {
  source_dest_check = false
  subnet_id = aws_subnet.security_zone_az1.id
  tags = {
    Name = "${var.project_prefix}-bigip-az1-security-zone-${random_id.build_suffix.hex}"
  }
}

resource "aws_eip" "bigip_az1_mgmt" {
  domain = "vpc"
  network_interface = aws_network_interface.bigip_az1_mgmt.id
  associate_with_private_ip = aws_network_interface.bigip_az1_mgmt.private_ip
  # The IGW needs to exist before the EIP can be created
  depends_on = [
    aws_internet_gateway.bigip_sandwich
  ]
  tags = {
    Name = "${var.project_prefix}-bigip-az1-mgmt-${random_id.build_suffix.hex}"
  }
}

resource "aws_instance" "bigip_az1" {

  availability_zone = local.aws_az1
  ami = data.aws_ami.F5BIG-IP_AMI.id
  instance_type = "${var.bigip_ec2_instance_type}"
  root_block_device {
    volume_size = 150
  }
  key_name = aws_key_pair.deployer.id
	user_data = templatefile("${path.module}/bigip_runtime_init_user_data.template",
    {
      bigip_admin_password = "${var.bigip_admin_password}",
      bigip_license_type = "${var.bigip_license_type == "BYOL" ? "BYOL" : "PAYG"}",
      bigip_license = "${var.bigip_license_az1}",
      f5_do_version = "${var.f5_do_version}",
      f5_do_schema_version = "${var.f5_do_schema_version}",
      f5_as3_version = "${var.f5_as3_version}",
      f5_as3_schema_version = "${var.f5_as3_schema_version}",
      f5_ts_version = "${var.f5_ts_version}",
      f5_ts_schema_version = "${var.f5_ts_schema_version}",
      f5_cf_version = "${var.f5_cf_version}",
    }
  )
  network_interface {
    network_interface_id = aws_network_interface.bigip_az1_mgmt.id
    device_index = 0
  }
  network_interface {
    network_interface_id = aws_network_interface.bigip_az1_client.id
    device_index = 1
  }
  network_interface {
    network_interface_id = aws_network_interface.bigip_az1_server.id
    device_index = 2
  }
  network_interface {
    network_interface_id = aws_network_interface.bigip_az1_security_zone.id
    device_index = 3 
  }
  # Let's ensure an EIP is provisioned so licensing and bigip-runtime-init runs successfully
  depends_on = [
    aws_eip.bigip_az1_mgmt
  ]
  tags = {
    Name = "${var.project_prefix}-bigip-az1-${random_id.build_suffix.hex}"
  }
}

##
## AZ2 F5 BIG-IP
##

resource "aws_network_interface" "bigip_az2_mgmt" {
  subnet_id = aws_subnet.management_az2.id
  # Disable IPV6 dual stack management because it breaks DO clustering
  ipv6_address_count = 0
  tags = {
    Name = "${var.project_prefix}-bigip-az2-mgmt-${random_id.build_suffix.hex}"
  }
}

resource "aws_network_interface" "bigip_az2_client" {
  source_dest_check = false
  subnet_id = aws_subnet.client_az2.id
  tags = {
    Name = "${var.project_prefix}-bigip-az2-client-${random_id.build_suffix.hex}"
  }
}

resource "aws_network_interface" "bigip_az2_server" {
  source_dest_check = false
  subnet_id = aws_subnet.server_az2.id
  tags = {
    Name = "${var.project_prefix}-bigip-az2-server-${random_id.build_suffix.hex}"
  }
}

resource "aws_network_interface" "bigip_az2_security_zone" {
  source_dest_check = false
  subnet_id = aws_subnet.security_zone_az2.id
  tags = {
    Name = "${var.project_prefix}-bigip-az2-security-zone-${random_id.build_suffix.hex}"
  }
}

resource "aws_eip" "bigip_az2_mgmt" {
  domain = "vpc"
  network_interface = aws_network_interface.bigip_az2_mgmt.id
  associate_with_private_ip = aws_network_interface.bigip_az2_mgmt.private_ip
  # The IGW needs to exist before the EIP can be created
  depends_on = [
    aws_internet_gateway.bigip_sandwich
  ]
  tags = {
    Name = "${var.project_prefix}-bigip-az2-mgmt-${random_id.build_suffix.hex}"
  }
}

resource "aws_instance" "bigip_az2" {

  availability_zone = local.aws_az2
  ami = data.aws_ami.F5BIG-IP_AMI.id
  instance_type = "${var.bigip_ec2_instance_type}"
  root_block_device {
    volume_size = 150
  }
  key_name = aws_key_pair.deployer.id

	user_data = templatefile("${path.module}/bigip_runtime_init_user_data.template",
    {
    bigip_admin_password = "${var.bigip_admin_password}",
    bigip_license_type = "${var.bigip_license_type == "BYOL" ? "BYOL" : "PAYG"}",
    bigip_license = "${var.bigip_license_az2}",
    f5_do_version = "${var.f5_do_version}",
    f5_do_schema_version = "${var.f5_do_schema_version}",
    f5_as3_version = "${var.f5_as3_version}",
    f5_as3_schema_version = "${var.f5_as3_schema_version}",
    f5_ts_version = "${var.f5_ts_version}",
    f5_ts_schema_version = "${var.f5_ts_schema_version}",
    f5_cf_version = "${var.f5_cf_version}",
    }
  )
  network_interface {
    network_interface_id = aws_network_interface.bigip_az2_mgmt.id
    device_index = 0
  }
  network_interface {
    network_interface_id = aws_network_interface.bigip_az2_client.id
    device_index = 1
  }
  network_interface {
    network_interface_id = aws_network_interface.bigip_az2_server.id
    device_index = 2
  }
  network_interface {
    network_interface_id = aws_network_interface.bigip_az2_security_zone.id
    device_index = 3 
  }
  # Let's ensure an EIP is provisioned so licensing and bigip-runtime-init runs successfully
  depends_on = [
    aws_eip.bigip_az2_mgmt
  ]
  tags = {
    Name = "${var.project_prefix}-bigip-az2-${random_id.build_suffix.hex}"
  }
}

############################################################
########################## Client ##########################
############################################################

##
## Client Server AZ1
##

resource "aws_network_interface" "client_az1" {
  subnet_id = aws_subnet.client_az1.id
  tags = {
    Name = "${var.project_prefix}-client-az1-${random_id.build_suffix.hex}"
  }
}

resource "aws_eip" "client_az1" {
  domain = "vpc"
  network_interface = aws_network_interface.client_az1.id
  associate_with_private_ip = aws_network_interface.client_az1.private_ip
  # The IGW needs to exist before the EIP can be created
  depends_on = [
    aws_internet_gateway.bigip_sandwich
  ]
  tags = {
    Name = "${var.project_prefix}-client-az1-${random_id.build_suffix.hex}"
  }
}

resource "aws_instance" "client_az1" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "${var.client_ec2_instance}"
  availability_zone = local.aws_az1
  key_name = aws_key_pair.deployer.id
	user_data = templatefile("${path.module}/linux_user_data.template", {})
  network_interface {
    network_interface_id = aws_network_interface.client_az1.id
    device_index = 0
  }
  # Let's ensure an EIP is provisioned so user-data can run successfully
  depends_on = [
    aws_eip.client_az1
  ]

  tags = {
    Name = "${var.project_prefix}-client-az1-${random_id.build_suffix.hex}"
  }

}

############################################################
########################## Server ##########################
############################################################

##
## Server Server AZ1
##

resource "aws_network_interface" "server_az1" {
  subnet_id = aws_subnet.server_az1.id
  tags = {
    Name = "${var.project_prefix}-server-az1-${random_id.build_suffix.hex}"
  }
}

resource "aws_eip" "server_az1" {
  domain = "vpc"
  network_interface = aws_network_interface.server_az1.id
  associate_with_private_ip = aws_network_interface.server_az1.private_ip
  # The IGW needs to exist before the EIP can be created
  depends_on = [
    aws_internet_gateway.bigip_sandwich
  ]
  tags = {
    Name = "${var.project_prefix}-server-az1-${random_id.build_suffix.hex}"
  }
}

resource "aws_instance" "server_az1" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "${var.server_ec2_instance}"
  availability_zone = local.aws_az1
  key_name = aws_key_pair.deployer.id
	user_data = templatefile("${path.module}/linux_user_data.template",{})
  network_interface {
    network_interface_id = aws_network_interface.server_az1.id
    device_index = 0
  }
  # Let's ensure an EIP is provisioned so user-data can run successfully
  depends_on = [
    aws_eip.server_az1
  ]
  tags = {
    Name = "${var.project_prefix}-server-az1-${random_id.build_suffix.hex}"
  }
}
