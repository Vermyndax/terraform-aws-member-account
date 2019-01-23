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
  provider = "aws.ops"
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

resource "aws_s3_bucket" "prod_codepipeline_artifact_bucket" {
  provider = "aws.prod"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  bucket = "${local.application}-prod-codepipeline-artifacts"
  acl    = "private"

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

resource "aws_s3_bucket_policy" "prod_codepipeline_artifact_bucket_policy" {
  provider = "aws.prod"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  bucket = "${aws_s3_bucket.prod_codepipeline_artifact_bucket.id}"
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
                "${aws_s3_bucket.prod_codepipeline_artifact_bucket.arn}",
                "${aws_s3_bucket.prod_codepipeline_artifact_bucket.arn}/*"
            ]
        }
    ]
}
BUCKETPOLICY
}

resource "aws_iam_role" "prod_codepipeline_role" {
  provider = "aws.prod"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-prod-codepipeline-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = "${merge(
    local.required_tags,
    map(
      "Environment", "prod",
    )
  )}"
}

resource "aws_iam_role_policy" "prod_codepipeline_policy" {
  provider = "aws.prod"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-prod-codepipeline-policy"
  role = "${aws_iam_role.prod_codepipeline_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.prod_codepipeline_artifact_bucket.arn}",
        "${aws_s3_bucket.prod_codepipeline_artifact_bucket.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Resource": "arn:aws:iam::${aws_organizations_account.dev.id}:role/${aws_iam_role.dev_codecommit_access_role.name}",
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  # tags = "${merge(
  #   local.required_tags,
  #   map(
  #     "Environment", "prod",
  #   )
  # )}"

}

resource "aws_iam_role" "prod_codebuild_role" {
  provider = "aws.prod"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-prod-codebuild-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = "${merge(
    local.required_tags,
    map(
      "Environment", "prod",
    )
  )}"
}

resource "aws_iam_role_policy" "prod_codebuild_policy" {
  provider = "aws.prod"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-prod-codebuild-policy"
  role = "${aws_iam_role.prod_codebuild_role.id}"

policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
       "s3:PutObject",
       "s3:GetObject",
       "s3:GetObjectVersion",
       "s3:GetBucketVersioning"
      ],
      "Resource": "*",
      "Effect": "Allow"
    },
    {
      "Action": [
          "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.prod_codepipeline_artifact_bucket.arn}",
        "${aws_s3_bucket.prod_codepipeline_artifact_bucket.arn}/*",
        "${aws_s3_bucket.prod_terraform_state_bucket.arn}",
        "${aws_s3_bucket.prod_terraform_state_bucket.arn}/*"
      ],
      "Effect": "Allow"
    },
    {
      "Action": [
        "codebuild:*"
      ],
      "Resource": [
        "${aws_codebuild_project.prod_provision.id}"
      ],
      "Effect": "Allow"
    },
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "*"
      ],
      "Effect": "Allow"
    },
    {
      "Action": [
        "kms:DescribeKey",
        "kms:GenerateDataKey*",
        "kms:Encrypt",
        "kms:ReEncrypt*",
        "kms:Decrypt"
      ],
      "Resource": [
        "${aws_kms_key.prod_s3_kms_key.arn}"
        ],
      "Effect": "Allow"
    },
    {
      "Action": [
        "sns:Publish"
      ],
      "Resource": "${aws_sns_topic.prod_sns_topic.arn}",
      "Effect": "Allow"
    },
    {
      "Action": [
        "ec2:*",
        "kms:CreateKey"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
POLICY

  # tags = "${merge(
  #   local.required_tags,
  #   map(
  #     "Environment", "prod",
  #   )
  # )}"

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