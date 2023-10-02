# f5_bigip_sandwich

Using Terraform to deploy a F5 BIG-IP VE in AWS.

This plan:
- Creates a single VPC across two AZs, with a client, server and management subnet in each.
- Deploys a BIG-IP VE in each AZ with an interface in each VLAN
- Deploys a Linux VM running Docker/Juice Shop in the client VLAN of AZ1
- Deploys a Linux VM running Docker/Juice Shpo in the server VLAN of AZ1

This Terraform plan is not supported by F5, Inc.
