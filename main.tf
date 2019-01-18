resource "aws_organizations_account" "child" {
  # provider = <master, inherited from top level>

  name  = "${var.account_name}"
  email = "${var.account_root_email}"
}

provider "aws" {
  alias = "child"

  assume_role {
    role_arn = "arn:aws:iam::${aws_organizations_account.child.id}:role/${var.org_iam_role_name}"
  }
}

# additional child account configuration goes here, using `provider = "aws.child"`

