#!/bin/bash

# Enable logging to file
export TF_LOG=warn
export TF_LOG_PATH=terraform.log
rm -f $TF_LOG_PATH

# init to ensure we have proper providers
terraform init --upgrade

# run the plan to ensure we have proper configuration
terraform plan -input=false -var-file=admin.tfvars -out tfplan
EXITCODE=$?

# apply the plan if the planning operation was successful
test $EXITCODE -eq 0 && terraform apply -input=false --auto-approve tfplan || echo "An error occurred while creating the Terraform plan"; 

# print timestamp of script completion
printf "$0 completed at $(date)"
