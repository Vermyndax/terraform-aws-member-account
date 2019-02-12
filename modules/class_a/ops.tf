### Ops Resources
#
# TODO: Add CloudWatch Event rule/Target for SNS notifications on CodePipeline events
#
# Additional IAM roles (future)
#
# S3 Terraform state bucket if create_terraform_state_buckets = true
# resource "aws_kms_key" "ops_s3_kms_key" {
#   provider = "aws.ops"
#   count = "${var.create_terraform_state_buckets == "true" ? 1 : 0}"
#   description = "This key is used to encrypt bucket objects"
#   deletion_window_in_days = 30
#   enable_key_rotation = "true"

#   policy = <<KMSPOLICY
# {
#   "Version": "2012-10-17",
#   "Id": "key-default-1",
#   "Statement": [
#     {
#       "Sid": "Enable IAM User Permissions",
#       "Effect": "Allow",
#       "Principal": {
#         "AWS": "arn:aws:iam::${aws_organizations_account.ops.id}:root"
#       },
#       "Action": "kms:*",
#       "Resource": "*"
#     },
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "AWS": "${aws_iam_role.dev_codecommit_access_role.arn}"
#       },
#       "Action": "kms:*",
#       "Resource": "*"
#     }
#   ]
# }
# KMSPOLICY

#   tags = "${merge(
#     local.required_tags,
#     map(
#       "Environment", "ops",
#     )
#   )}"

# }

# resource "aws_kms_alias" "ops_s3_kms_key_name" {
#   provider = "aws.ops"
#   count = "${var.create_terraform_state_buckets == "true" ? 1 : 0}"
#   name = "alias/ops-s3-kms-key"
#   target_key_id = "${aws_kms_key.ops_s3_kms_key.key_id}"
# }

resource "aws_s3_bucket" "ops_terraform_state_bucket" {
  provider = "aws.ops"
  count = "${var.create_terraform_state_buckets == "true" ? 1 : 0}"
  bucket = "${local.application}-ops-terraform-state"

  versioning {
    enabled = true
  }

  server_side_encryption = "AES256"

  # server_side_encryption_configuration {
  #   rule {
  #     apply_server_side_encryption_by_default {
  #       kms_master_key_id = "${aws_kms_key.ops_s3_kms_key.arn}"
  #       sse_algorithm     = "aws:kms"
  #     }
  #   }
  # }

  tags = "${merge(
    local.required_tags,
    map(
      "Environment", "ops",
    )
  )}"
}

# CodePipelines (3 of them!) if create_pipelines = true

resource "aws_s3_bucket" "ops_codepipeline_artifact_bucket" {
  provider = "aws.ops"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  bucket = "${local.application}-ops-codepipeline-artifacts"
  acl    = "private"

  server_side_encryption = "AES256"

  # server_side_encryption_configuration {
  #   rule {
  #     apply_server_side_encryption_by_default {
  #       kms_master_key_id = "${aws_kms_key.ops_s3_kms_key.arn}"
  #       sse_algorithm     = "aws:kms"
  #     }
  #   }
  # }

  tags = "${merge(
    local.required_tags,
    map(
      "Environment", "ops",
    )
  )}"
}

resource "aws_s3_bucket_policy" "ops_codepipeline_artifact_bucket_policy" {
  provider = "aws.ops"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  bucket = "${aws_s3_bucket.ops_codepipeline_artifact_bucket.id}"
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
                "${aws_s3_bucket.ops_codepipeline_artifact_bucket.arn}",
                "${aws_s3_bucket.ops_codepipeline_artifact_bucket.arn}/*"
            ]
        }
    ]
}
BUCKETPOLICY
}

resource "aws_iam_role" "ops_codepipeline_role" {
  provider = "aws.ops"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-ops-codepipeline-role"

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
      "Environment", "ops",
    )
  )}"
}

resource "aws_iam_role_policy" "ops_codepipeline_policy" {
  provider = "aws.ops"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-ops-codepipeline-policy"
  role = "${aws_iam_role.ops_codepipeline_role.id}"

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
        "${aws_s3_bucket.ops_codepipeline_artifact_bucket.arn}",
        "${aws_s3_bucket.ops_codepipeline_artifact_bucket.arn}/*"
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
  #     "Environment", "ops",
  #   )
  # )}"

}

# CodeBuild dependencies

resource "aws_iam_role" "ops_codebuild_role" {
  provider = "aws.ops"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-ops-codebuild-role"

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
      "Environment", "ops",
    )
  )}"
}

resource "aws_iam_role_policy" "ops_codebuild_policy" {
  provider = "aws.ops"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-ops-codebuild-policy"
  role = "${aws_iam_role.ops_codebuild_role.id}"

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
        "${aws_s3_bucket.ops_codepipeline_artifact_bucket.arn}",
        "${aws_s3_bucket.ops_codepipeline_artifact_bucket.arn}/*",
        "${aws_s3_bucket.ops_terraform_state_bucket.arn}",
        "${aws_s3_bucket.ops_terraform_state_bucket.arn}/*"
      ],
      "Effect": "Allow"
    },
    {
      "Action": [
        "codebuild:*"
      ],
      "Resource": [
        "${aws_codebuild_project.ops_provision.id}"
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
        "sns:Publish"
      ],
      "Resource": "${aws_sns_topic.ops_sns_topic.arn}",
      "Effect": "Allow"
    },
    {
      "Action": [
        "ec2:*",
        "kms:*"
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
  #     "Environment", "ops",
  #   )
  # )}"

}

# CodeBuild projects

resource "aws_codebuild_project" "ops_provision" {
  provider = "aws.ops"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-ops-provision"
  build_timeout = "${var.codebuild_timeout}"
  service_role = "${aws_iam_role.ops_codebuild_role.arn}"
  # encryption_key = "${aws_kms_key.ops_s3_kms_key.arn}"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "${var.build_compute_type}"
    image = "${var.build_image}"
    type  = "LINUX_CONTAINER"
    privileged_mode = "${var.build_privileged_override}"
  }

  source {
    type = "CODEPIPELINE"
    buildspec = <<BUILDSPEC
version: 0.2
phases:
  install:
    commands:
      - yum -y install jq
      - cd /tmp && curl -o terraform.zip https://releases.hashicorp.com/terraform/${var.terraform_version}/terraform_${var.terraform_version}_linux_amd64.zip && echo "${var.terraform_sha256} terraform.zip" | sha256sum -c --quiet && unzip terraform.zip && mv terraform /usr/bin
  build:
    commands:
      - cd $CODEBUILD_SRC_DIR/terraform
      - terraform init -backend=true -backend-config="bucket=${aws_s3_bucket.ops_terraform_state_bucket.id}" -backend-config="key=${var.terraform_state_file}" -backend-config="region=${var.region}" -no-color
      - terraform plan -no-color
      - terraform apply -auto-approve -no-color
BUILDSPEC
  }

  tags = "${merge(
    local.required_tags,
    map(
      "Environment", "ops",
    )
  )}"
}

# SNS topic if create_sns_topic = true
resource "aws_sns_topic" "ops_sns_topic" {
  provider = "aws.ops"
  count = "${var.create_sns_topic == "true" ? 1 : 0}"
  name = "${var.tag_application_id}-ops-notifications"

  # tags = "${merge(
  #   local.required_tags,
  #   map(
  #     "Environment", "ops",
  #   )
  # )}"
}

# Default SNS subscriptions if create_default_sns_subscriptions = true
resource "aws_sns_topic_subscription" "sns-topic" {
  provider = "aws.ops"
  count = "${var.create_default_sns_subscriptions == "true" ? 1 : 0}"
  topic_arn = "${aws_sns_topic.ops_sns_topic.arn}"
  protocol  = "sms"
  endpoint  = "${var.default_sns_sms}"
}
