# This file is included for Terraform's happiness only.
# ops.tf = ops account
# prod.tf = prod account
# staging.tf = staging account
# dev.tf = dev account

# Locals

locals {
  application = "${var.tag_application_id}"
  required_tags = {
    ApplicationID = "${var.tag_application_id}"
  }
}

### OPS ACCOUNT RESOURCES
resource "aws_organizations_account" "ops" {
  # provider = <master, inherited from top level>

  name  = "${var.account_name}-ops"
  email = "${var.ops_account_root_email}"

  # Adding a sleep for 120 to prevent a known race condition.
  provisioner "local-exec" {
    command = "sleep 120"
  }
}

provider "aws" {
  alias = "ops"

  assume_role {
    # OrganizationAccountAccessRole is created by AWS by default, so going to hard-code this for now instead of providing an opportunity to mess it up.
    # role_arn = "arn:aws:iam::${aws_organizations_account.child.id}:role/${var.org_iam_role_name}"
    role_arn = "arn:aws:iam::${aws_organizations_account.ops.id}:role/OrganizationAccountAccessRole"
  }
}

resource "aws_organizations_account" "dev" {
  # provider = <master, inherited from top level>
  depends_on = ["aws_organizations_account.ops"]

  name  = "${var.account_name}-dev"
  email = "${var.dev_account_root_email}"

  # Adding a sleep for 120 to prevent a known race condition.
  provisioner "local-exec" {
    command = "sleep 120"
  }
}

provider "aws" {
  alias = "dev"

  assume_role {
    # OrganizationAccountAccessRole is created by AWS by default, so going to hard-code this for now instead of providing an opportunity to mess it up.
    # role_arn = "arn:aws:iam::${aws_organizations_account.child.id}:role/${var.org_iam_role_name}"
    role_arn = "arn:aws:iam::${aws_organizations_account.dev.id}:role/OrganizationAccountAccessRole"
  }
}

resource "aws_organizations_account" "staging" {
  # provider = <master, inherited from top level>
  depends_on = ["aws_organizations_account.dev"]
    
  name  = "${var.account_name}-staging"
  email = "${var.staging_account_root_email}"

  # Adding a sleep for 120 to prevent a known race condition.
  provisioner "local-exec" {
    command = "sleep 120"
  }
}

provider "aws" {
  alias = "staging"

  assume_role {
    # OrganizationAccountAccessRole is created by AWS by default, so going to hard-code this for now instead of providing an opportunity to mess it up.
    # role_arn = "arn:aws:iam::${aws_organizations_account.child.id}:role/${var.org_iam_role_name}"
    role_arn = "arn:aws:iam::${aws_organizations_account.staging.id}:role/OrganizationAccountAccessRole"
  }
}

resource "aws_organizations_account" "prod" {
  # provider = <master, inherited from top level>
    depends_on = ["aws_organizations_account.staging"]

  name  = "${var.account_name}-prod"
  email = "${var.prod_account_root_email}"

  # Adding a sleep for 120 to prevent a known race condition.
  provisioner "local-exec" {
    command = "sleep 120"
  }
}

provider "aws" {
  alias = "prod"

  assume_role {
    # OrganizationAccountAccessRole is created by AWS by default, so going to hard-code this for now instead of providing an opportunity to mess it up.
    # role_arn = "arn:aws:iam::${aws_organizations_account.child.id}:role/${var.org_iam_role_name}"
    role_arn = "arn:aws:iam::${aws_organizations_account.prod.id}:role/OrganizationAccountAccessRole"
  }
}