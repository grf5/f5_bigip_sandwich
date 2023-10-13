#!/bin/bash

echo "This will destroy your BIG-IPs and recreate them from scratch, no going back from here - Press enter to continue"
# pause to make sure!
read -r -p "Are you sure? [y/N] " response


# Enable logging to file
export TF_LOG=warn
export TF_LOG_PATH=terraform.log
rm -f $TF_LOG_PATH

# init to ensure we have proper providers
terraform init --upgrade

# run the plan to ensure we have proper configuration
terraform plan -replace="aws_instance.bigip_az1" -replace="aws_instance.bigip_az2" -input=false -compact-warnings -var-file=admin.tfvars -out tfplan
EXITCODE=$?

# apply the plan if the planning operation was successful
test $EXITCODE -eq 0 && terraform apply -input=false -auto-approve -compact-warnings tfplan || echo "An error occurred while creating the Terraform plan"; 

# print timestamp of script completion
printf "$0 completed at $(date)"
