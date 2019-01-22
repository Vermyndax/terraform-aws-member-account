variable "region" {
  description = "Region. It's used in some places."
  default = "us-east-1"
}

variable "account_name" {
  type = "string"
}

variable "ops_account_root_email" {
  type = "string"
}

variable "dev_account_root_email" {
  type = "string"
}

variable "staging_account_root_email" {
  type = "string"
}

variable "prod_account_root_email" {
  type = "string"
}

# variable "org_iam_role_name" {
#   default     = "OrganizationAccountAccessRole"
#   description = "Role used for cross-account access from the master to the member"
# }

variable "create_iam_roles" {
  default     = "true"
  description = "Boolean to define whether or not to create the IAM roles in this account."
}

# variable "environment" {
#     descriptiion = "Environment that will be set for the account. (Ex: prod, dev, text, ops)"
# }

variable "tag_application_id" {
  description = "Application ID to set for tags. Required."
}

variable "create_pipelines" {
  description = "Boolean to control whether or not to create the CodePipelines (should only be used in the ops account). Default: false."
  default = "false"
}

variable "create_terraform_state_buckets" {
  description = "Boolean to control whether or not to create Terraform S3 buckets in each account. Default: true."
  default = "true"
}

variable "create_codecommit_repo" {
  description = "Boolean to control whether or not to create a CodeCommit repo. If you plan to use another git repo of some kind, set this to false. Default: false. CodeCommit repo should only be created in the ops account."
  default = "false"
}

variable "create_sns_topic" {
  description = "Boolean to control whether or not to create a default SNS notification topic. Default: true. Note that you'll still need to manually add subscriptions other than the default ops notifications."
  default = "true"
}

variable "create_default_sns_subscriptions" {
  description = "Boolean to control whether or not to create default SNS subscriptions. Default: true."
  default = "true"
}

variable "default_sns_sms" {
  description = "Default SMS number for default subscriptions."
}

variable "codebuild_timeout" {
  description = "Timeout setting for CodeBuild projects (in minutes). Default: 5"
  default = "5"
}

variable "build_compute_type" {
    description = "Build instance type to use for the CodeBuild project. Default: BUILD_GENERAL1_SMALL."
    default = "BUILD_GENERAL1_SMALL"
}

variable "build_image" {
    description = "Managed build image for CodeBuild. Default: aws/codebuild/ubuntu-base:14.04"
    default = "aws/codebuild/ubuntu-base:14.04"
}

variable "build_privileged_override" {
  description = "Set the build privileged override to 'true' if you are not using a CodeBuild supported Docker base image. This is only relevant to building Docker images."
  default     = "false"
}

variable "terraform_version" {
  description = "Version of Terraform to install on build CodePipeline. Default: 0.11.11. CAUTION: If you change this, you MUST get the SHA256 hash to match the version you want and specify it in terraform_sha256."
  default = "0.11.11"
}

variable "terraform_sha256" {
  description = "SHA256 hash of the Terraform version you want. Default is specified for 0.11.11_linux_amd64.zip. If you want a new version of Terraform and you alter terraform_version, you must update this variable for the new binary you want."
  default = "94504f4a67bad612b5c8e3a4b7ce6ca2772b3c1559630dfd71e9c519e3d6149c"
}

variable "terraform_state_file" {
  description = "Name of the Terraform state file for the account. Default: terraform.tfstate."
  default = "terraform.tfstate"
}

### Variables below are commented out until they are implemented in a future revision.
#
# # Change default value to true for production code.
# variable "enable_member_guardduty" {
#   description = "Enable guardduty and integrate with monitoring account true/false"
#   default = "false"
# }

# # Modify python script to pass it during module call
# variable "guardduty_master_detector_id" {
#   description = "Enable guardduty and integrate with monitoring account true/false"
# }


# variable "authlanding_prod_account_id" {
#   description = "AWS Account ID of the Authlanding account (if using one)."
# }

# variable "monitoring_prod_account_id" {
#   description = "AWS Account ID of the monitoring account"
# }