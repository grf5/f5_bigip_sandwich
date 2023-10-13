output "ServerAZ1PrivateIP" {
  description = "the private IP address of the Juice Shop server in AZ1"
  value = aws_network_interface.server_az1.private_ip
}
output "ClientAZ1PrivateIP" {
  description = "the private IP address of the Ubuntu client in AZ1"
  value = aws_network_interface.client_az1.private_ip
}
output "BIG-IP_AZ1_Mgmt_URL" {
  description = "URL for managing the BIG-IP in AZ1"
  value = format("https://%s/",aws_eip.bigip_az1_mgmt.public_ip)
}
output "BIG-IP_AZ2_Mgmt_URL" {
  description = "URL for managing the BIG-IP in AZ2"
  value = format("https://%s/",aws_eip.bigip_az2_mgmt.public_ip)
}
output "SSH_Bash_aliases" {
  description = "cut/paste block to create ssh aliases"
  value =<<EOT
# SSH Aliases
alias client1='ssh ubuntu@${aws_eip.client_az1.public_ip} -p 22 -o StrictHostKeyChecking=off -i "${local_sensitive_file.newkey_pem.filename}"'
alias server1='ssh ubuntu@${aws_eip.server_az1.public_ip} -p 22 -o StrictHostKeyChecking=off -i "${local_sensitive_file.newkey_pem.filename}"'
alias bigip-az1='ssh admin@${aws_eip.bigip_az1_mgmt.public_ip} -p 22 -o StrictHostKeyChecking=off -i "${local_sensitive_file.newkey_pem.filename}"'
alias bigip-az2='ssh admin@${aws_eip.bigip_az2_mgmt.public_ip} -p 22 -o StrictHostKeyChecking=off -i "${local_sensitive_file.newkey_pem.filename}"'
EOT
}