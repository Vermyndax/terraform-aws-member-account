resource "aws_kms_key" "dev_s3_kms_key" {
  provider = "aws.ops"
  count = "${var.create_terraform_state_buckets == "true" ? 1 : 0}"
  description = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 30
  enable_key_rotation = "true"

  tags = "${merge(
    local.required_tags,
    map(
      "Environment", "dev",
    )
  )}"

}

resource "aws_kms_alias" "dev_s3_kms_key_name" {
  provider = "aws.ops"
  count = "${var.create_terraform_state_buckets == "true" ? 1 : 0}"
  name = "alias/dev-s3-kms-key"
  target_key_id = "${aws_kms_key.dev_s3_kms_key.key_id}"
}

resource "aws_s3_bucket" "dev_terraform_state_bucket" {
  provider = "aws.ops"
  count = "${var.create_terraform_state_buckets == "true" ? 1 : 0}"
  bucket = "${var.tag_application_id}-dev-terraform-state"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = "${aws_kms_key.dev_s3_kms_key.arn}"
        sse_algorithm     = "aws:kms"
      }
    }
  }

  tags = "${merge(
    local.required_tags,
    map(
      "Environment", "dev",
    )
  )}"
}

resource "aws_sns_topic" "dev_sns_topic" {
  provider = "aws.dev"
  count = "${var.create_sns_topic == "true" ? 1 : 0}"
  name = "${var.tag_application_id}-dev-notifications"

  # tags = "${merge(
  #   local.required_tags,
  #   map(
  #     "Environment", "dev",
  #   )
  # )}"
}

# CodeCommit repo if create_codecommit_repo = true
# TODO: Set up IAM policy for master branch protection
# TODO: Find a way to create the 3 default branches - dev, staging, prod
#
resource "aws_codecommit_repository" "default_codecommit_repo" {
  provider = "aws.dev"
  count = "${var.create_codecommit_repo == "true" ? 1 : 0}"
  repository_name = "${var.tag_application_id}"
  default_branch = "master"

  # tags = "${merge(
  #   local.required_tags,
  #   map(
  #     "Environment", "ops",
  #   )
  # )}"
}

resource "aws_codecommit_trigger" "notify_sns_on_repo" {
  provider = "aws.dev"
  count = "${var.create_sns_topic == "true" ? 1 : 0}"
  depends_on      = ["aws_codecommit_repository.default_codecommit_repo"]
  repository_name = "${var.tag_application_id}"

  trigger {
    name            = "all-notifications"
    events          = ["all"]
    destination_arn = "${aws_sns_topic.dev_sns_topic.arn}"
  }
}