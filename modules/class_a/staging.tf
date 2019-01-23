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

resource "aws_s3_bucket" "staging_codepipeline_artifact_bucket" {
  provider = "aws.staging"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  bucket = "${local.application}-staging-codepipeline-artifacts"
  acl    = "private"

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

resource "aws_s3_bucket_policy" "staging_codepipeline_artifact_bucket_policy" {
  provider = "aws.staging"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  bucket = "${aws_s3_bucket.staging_codepipeline_artifact_bucket.id}"
  policy = <<BUCKETPOLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "${aws_iam_role.dev_codecommit_access_role.arn}"
            },
            "Action": "s3:*",
            "Resource": [
                "${aws_s3_bucket.staging_codepipeline_artifact_bucket.arn}",
                "${aws_s3_bucket.staging_codepipeline_artifact_bucket.arn}/*"
            ]
        }
    ]
}
BUCKETPOLICY
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