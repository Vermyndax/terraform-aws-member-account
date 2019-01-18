output "account_id" {
  value = "${aws_organizations_account.child.id}"
}

output "root_arn" {
  value = "arn:aws:iam::${aws_organizations_account.child.id}:root"
}