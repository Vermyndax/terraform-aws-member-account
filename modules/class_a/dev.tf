# resource "aws_kms_key" "dev_s3_kms_key" {
#   provider = "aws.dev"
#   count = "${var.create_terraform_state_buckets == "true" ? 1 : 0}"
#   description = "This key is used to encrypt bucket objects"
#   deletion_window_in_days = 30
#   enable_key_rotation = "true"

#   policy =<<KMSPOLICY
# {
#   "Version": "2012-10-17",
#   "Id": "key-default-1",
#   "Statement": [
#     {
#       "Sid": "Enable IAM User Permissions",
#       "Effect": "Allow",
#       "Principal": {
#         "AWS": [
#           "arn:aws:iam::${aws_organizations_account.dev.id}:root",
#           "${aws_iam_role.dev_codebuild_role.arn}",
#           "${aws_iam_role.dev_codecommit_access_role.arn}",
#           "${aws_iam_role.dev_codepipeline_role.arn}"
#         ]
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
#       "Environment", "dev",
#     )
#   )}"

# }

# resource "aws_kms_alias" "dev_s3_kms_key_name" {
#   provider = "aws.dev"
#   count = "${var.create_terraform_state_buckets == "true" ? 1 : 0}"
#   name = "alias/dev-s3-kms-key"
#   target_key_id = "${aws_kms_key.dev_s3_kms_key.key_id}"
# }

resource "aws_s3_bucket" "dev_terraform_state_bucket" {
  provider = "aws.dev"
  count = "${var.create_terraform_state_buckets == "true" ? 1 : 0}"
  bucket = "${local.application}-dev-terraform-state"

  versioning {
    enabled = true
  }

  server_side_encryption = "AES256"

  # server_side_encryption_configuration {
  #   rule {
  #     apply_server_side_encryption_by_default {
  #       kms_master_key_id = "${aws_kms_key.dev_s3_kms_key.arn}"
  #       sse_algorithm     = "aws:kms"
  #     }
  #   }
  # }

  tags = "${merge(
    local.required_tags,
    map(
      "Environment", "dev",
    )
  )}"
}

resource "aws_s3_bucket" "dev_codepipeline_artifact_bucket" {
  provider = "aws.dev"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  bucket = "${local.application}-dev-codepipeline-artifacts"
  acl    = "private"

  server_side_encryption = "AES256"

  # server_side_encryption_configuration {
  #   rule {
  #     apply_server_side_encryption_by_default {
  #       kms_master_key_id = "${aws_kms_key.dev_s3_kms_key.arn}"
  #       sse_algorithm     = "aws:kms"
  #     }
  #   }
  # }

  tags = "${merge(
    local.required_tags,
    map(
      "Environment", "dev",
    )
  )}"
}

resource "aws_s3_bucket_policy" "dev_codepipeline_artifact_bucket_policy" {
  provider = "aws.dev"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  bucket = "${aws_s3_bucket.dev_codepipeline_artifact_bucket.id}"
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
                "${aws_s3_bucket.dev_codepipeline_artifact_bucket.arn}",
                "${aws_s3_bucket.dev_codepipeline_artifact_bucket.arn}/*"
            ]
        }
    ]
}
BUCKETPOLICY
}

# IAM role for ops CodePipeline role to assume for CodeCommit access
resource "aws_iam_role" "dev_codecommit_access_role" {
  provider = "aws.dev"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-dev-codecommit-access-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "${aws_organizations_account.ops.id}",
          "${aws_organizations_account.dev.id}",
          "${aws_organizations_account.staging.id}",
          "${aws_organizations_account.prod.id}"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = "${merge(
    local.required_tags,
    map(
      "Environment", "dev",
    )
  )}"

}

resource "aws_iam_role_policy" "dev_codecommit_access_role_policy" {
  provider = "aws.dev"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-dev-codecommit-access-role-policy"
  role = "${aws_iam_role.dev_codecommit_access_role.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "codecommit:BatchGetRepositories",
        "codecommit:Get*",
        "codecommit:GitPull",
        "codecommit:List*",
        "codecommit:CancelUploadArchive",
        "codecommit:UploadArchive",
        "s3:*"
      ],
      "Resource": "*",
      "Effect": "Allow"
    },
  ]
}
POLICY
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

resource "aws_iam_role" "dev_codepipeline_role" {
  provider = "aws.dev"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-dev-codepipeline-role"

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
      "Environment", "dev",
    )
  )}"
}

resource "aws_iam_role_policy" "dev_codepipeline_policy" {
  provider = "aws.dev"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-dev-codepipeline-policy"
  role = "${aws_iam_role.dev_codepipeline_role.id}"

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
        "${aws_s3_bucket.dev_codepipeline_artifact_bucket.arn}",
        "${aws_s3_bucket.dev_codepipeline_artifact_bucket.arn}/*"
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
      "Action": [
        "sns:Publish"
      ],
      "Resource": "${aws_sns_topic.dev_sns_topic.arn}",
      "Effect": "Allow"
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
  #     "Environment", "dev",
  #   )
  # )}"

}

# CodeCommit repo if create_codecommit_repo = true
# TODO: Set up IAM policy for master branch protection
# TODO: Find a way to create the 3 default branches - dev, staging, prod
#

resource "aws_iam_role" "dev_codebuild_role" {
  provider = "aws.dev"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-dev-codebuild-role"

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
      "Environment", "dev",
    )
  )}"
}

resource "aws_iam_role_policy" "dev_codebuild_policy" {
  provider = "aws.dev"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-dev-codebuild-policy"
  role = "${aws_iam_role.dev_codebuild_role.id}"

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
        "codecommit:*"
      ],
      "Resource": "${aws_codecommit_repository.default_codecommit_repo.arn}",
      "Effect": "Allow"
    },
    {
      "Action": [
          "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.dev_codepipeline_artifact_bucket.arn}",
        "${aws_s3_bucket.dev_codepipeline_artifact_bucket.arn}/*",
        "${aws_s3_bucket.dev_terraform_state_bucket.arn}",
        "${aws_s3_bucket.dev_terraform_state_bucket.arn}/*"
      ],
      "Effect": "Allow"
    },
    {
      "Action": [
        "codebuild:*"
      ],
      "Resource": [
        "${aws_codebuild_project.dev_provision.id}",
        "${aws_codebuild_project.git_merge_dev_to_staging.id}"
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
      "Resource": "${aws_sns_topic.dev_sns_topic.arn}",
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
  #     "Environment", "dev",
  #   )
  # )}"

}

resource "aws_codebuild_project" "dev_provision" {
  provider = "aws.dev"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-dev-provision"
  build_timeout = "${var.codebuild_timeout}"
  service_role = "${aws_iam_role.dev_codebuild_role.arn}"
  # encryption_key = "${aws_kms_key.dev_s3_kms_key.arn}"

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
      - terraform init -backend=true -backend-config="bucket=${aws_s3_bucket.dev_terraform_state_bucket.id}" -backend-config="key=${var.terraform_state_file}" -backend-config="region=${var.region}" -no-color
      - terraform plan -no-color
      - terraform apply -auto-approve -no-color
BUILDSPEC
  }

  tags = "${merge(
    local.required_tags,
    map(
      "Environment", "dev",
    )
  )}"
}

resource "aws_codebuild_project" "git_merge_dev_to_staging" {
  provider = "aws.dev"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-git-merge-dev-to-staging"
  build_timeout = "${var.codebuild_timeout}"
  service_role = "${aws_iam_role.dev_codebuild_role.arn}"
  # encryption_key = "${aws_kms_key.dev_s3_kms_key.arn}"

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
    # TODO: Need to detect whether or not they're using a CodeCommit repo, maybe it's something else!
    buildspec = <<BUILDSPEC
version: 0.2
phases:
  install:
    commands:
      - git config --global credential.helper '!aws codecommit credential-helper $@'
      - git config --global credential.UseHttpPath true
  post_build:
    commands:
      - git clone ${aws_codecommit_repository.default_codecommit_repo.clone_url_http}
      - cd ${aws_codecommit_repository.default_codecommit_repo.repository_name}
      - git checkout staging
      - git merge origin/dev
      - git push -u origin staging
BUILDSPEC
  }

  tags = "${merge(
    local.required_tags,
    map(
      "Environment", "dev",
    )
  )}"
}

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

# TODO: Add parameters to the repo activity below to make it configurable with other git repos
# TODO: Provide optional flag to tear down Dev Terraform with a boolean (terraform destroy stage)
resource "aws_codepipeline" "dev_codepipeline" {
  provider = "aws.dev"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name     = "${var.tag_application_id}-dev"
  role_arn = "${aws_iam_role.dev_codepipeline_role.arn}"

  artifact_store {
    location = "${aws_s3_bucket.dev_codepipeline_artifact_bucket.bucket}"
    type = "S3"

    # encryption_key {
    #   id = "${aws_kms_alias.dev_s3_kms_key_name.arn}"
    #   type = "KMS"
    # }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["${var.tag_application_id}-dev-artifacts-from-source"]
      role_arn = "${aws_iam_role.dev_codecommit_access_role.arn}"

      configuration {
        RepositoryName = "${aws_codecommit_repository.default_codecommit_repo.repository_name}"
        BranchName = "dev"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["${var.tag_application_id}-dev-artifacts-from-source"]
      version         = "1"

      configuration {
        ProjectName = "${var.tag_application_id}-dev-provision"
      }
    }
  }

  stage {
    name = "Dev-Approval"

    action {
      name            = "Approval"
      category        = "Approval"
      owner           = "AWS"
      provider        = "Manual"
      version         = "1"

      configuration {
        NotificationArn = "${aws_sns_topic.dev_sns_topic.arn}"
        # CustomData = "${var.dev_approve_comment}"
        CustomData = "Please approve changes in the dev environment so it can be promoted to staging."
        # ExternalEntityLink = "${var.dev_application_external_url}"
      }
    }
  }

    stage {
      name = "Git-Merge-Dev-To-Staging"

      action {
        name            = "Git-Merge-Dev-To-Staging"
        category        = "Build"
        owner           = "AWS"
        provider        = "CodeBuild"
        input_artifacts = ["${var.tag_application_id}-dev-artifacts-from-source"]
        version         = "1"

        configuration {
          ProjectName = "${var.tag_application_id}-git-merge-dev-to-staging"
        }
    }
  }

  # tags = "${merge(
  #   local.required_tags,
  #   map(
  #     "Environment", "dev",
  #   )
  # )}"

}