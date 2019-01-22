output "ops_account_id" {
  value = "${aws_organizations_account.ops.id}"
}

output "ops_root_arn" {
  value = "arn:aws:iam::${aws_organizations_account.ops.id}:root"
}

output "dev_account_id" {
  value = "${aws_organizations_account.dev.id}"
}

output "dev_root_arn" {
  value = "arn:aws:iam::${aws_organizations_account.dev.id}:root"
}

output "staging_account_id" {
  value = "${aws_organizations_account.staging.id}"
}

output "staging_root_arn" {
  value = "arn:aws:iam::${aws_organizations_account.staging.id}:root"
}

output "prod_account_id" {
  value = "${aws_organizations_account.prod.id}"
}

output "prod_root_arn" {
  value = "arn:aws:iam::${aws_organizations_account.prod.id}:root"
}