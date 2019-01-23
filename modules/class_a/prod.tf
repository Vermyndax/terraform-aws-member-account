resource "aws_kms_key" "prod_s3_kms_key" {
  provider = "aws.prod"
  count = "${var.create_terraform_state_buckets == "true" ? 1 : 0}"
  description = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 30
  enable_key_rotation = "true"

  tags = "${merge(
    local.required_tags,
    map(
      "Environment", "prod",
    )
  )}"

}

resource "aws_kms_alias" "prod_s3_kms_key_name" {
  provider = "aws.prod"
  count = "${var.create_terraform_state_buckets == "true" ? 1 : 0}"
  name = "alias/prod-s3-kms-key"
  target_key_id = "${aws_kms_key.prod_s3_kms_key.key_id}"
}

resource "aws_s3_bucket" "prod_terraform_state_bucket" {
  provider = "aws.prod"
  count = "${var.create_terraform_state_buckets == "true" ? 1 : 0}"
  bucket = "${local.application}-prod-terraform-state"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = "${aws_kms_key.prod_s3_kms_key.arn}"
        sse_algorithm     = "aws:kms"
      }
    }
  }

  tags = "${merge(
    local.required_tags,
    map(
      "Environment", "prod",
    )
  )}"
}

resource "aws_sns_topic" "prod_sns_topic" {
  provider = "aws.prod"
  count = "${var.create_sns_topic == "true" ? 1 : 0}"
  name = "${var.tag_application_id}-prod-notifications"

  # tags = "${merge(
  #   local.required_tags,
  #   map(
  #     "Environment", "prod",
  #   )
  # )}"
}