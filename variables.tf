variable "account_name" {
  type = "string"
}

variable "account_root_email" {
  type = "string"
}

variable "org_iam_role_name" {
  default     = "OrganizationAccountAccessRole"
  description = "Role used for cross-account access from the master to the member"
}

variable "create_iam_roles" {
  default     = "true"
  description = "Boolean to define whether or not to create the IAM roles in this account."
}

variable "environment" {
    descriptiion = "Environment that will be set for the account. (Ex: prod, dev, text, ops)"
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