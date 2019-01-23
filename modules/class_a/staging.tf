resource "aws_kms_key" "staging_s3_kms_key" {
  provider = "aws.staging"
  count = "${var.create_terraform_state_buckets == "true" ? 1 : 0}"
  description = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 30
  enable_key_rotation = "true"

  tags = "${merge(
    local.required_tags,
    map(
      "Environment", "staging",
    )
  )}"

}

resource "aws_kms_alias" "staging_s3_kms_key_name" {
  provider = "aws.staging"
  count = "${var.create_terraform_state_buckets == "true" ? 1 : 0}"
  name = "alias/staging-s3-kms-key"
  target_key_id = "${aws_kms_key.staging_s3_kms_key.key_id}"
}

resource "aws_s3_bucket" "staging_terraform_state_bucket" {
  provider = "aws.staging"
  count = "${var.create_terraform_state_buckets == "true" ? 1 : 0}"
  bucket = "${local.application}-staging-terraform-state"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = "${aws_kms_key.staging_s3_kms_key.arn}"
        sse_algorithm     = "aws:kms"
      }
    }
  }

  tags = "${merge(
    local.required_tags,
    map(
      "Environment", "staging",
    )
  )}"
}

resource "aws_sns_topic" "staging_sns_topic" {
  provider = "aws.staging"
  count = "${var.create_sns_topic == "true" ? 1 : 0}"
  name = "${var.tag_application_id}-staging-notifications"

  # tags = "${merge(
  #   local.required_tags,
  #   map(
  #     "Environment", "staging",
  #   )
  # )}"
}