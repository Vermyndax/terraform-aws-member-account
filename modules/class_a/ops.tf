### Ops Resources
#
# TODO: Add CloudWatch Event rule/Target for SNS notifications on CodePipeline events
#
# Additional IAM roles (future)
#
# S3 Terraform state bucket if create_terraform_state_buckets = true
resource "aws_kms_key" "ops_s3_kms_key" {
  provider = "aws.ops"
  count = "${var.create_terraform_state_buckets == "true" ? 1 : 0}"
  description = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 30
  enable_key_rotation = "true"

  tags = "${merge(
    local.required_tags,
    map(
      "Environment", "ops",
    )
  )}"

}

resource "aws_kms_alias" "ops_s3_kms_key_name" {
  provider = "aws.ops"
  count = "${var.create_terraform_state_buckets == "true" ? 1 : 0}"
  name = "alias/ops-s3-kms-key"
  target_key_id = "${aws_kms_key.ops_s3_kms_key.key_id}"
}

resource "aws_s3_bucket" "ops_terraform_state_bucket" {
  provider = "aws.ops"
  count = "${var.create_terraform_state_buckets == "true" ? 1 : 0}"
  bucket = "${local.application}-ops-terraform-state"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = "${aws_kms_key.ops_s3_kms_key.arn}"
        sse_algorithm     = "aws:kms"
      }
    }
  }

  tags = "${merge(
    local.required_tags,
    map(
      "Environment", "ops",
    )
  )}"
}

# CodePipelines (3 of them!) if create_pipelines = true

resource "aws_s3_bucket" "codepipeline_artifact_bucket" {
  provider = "aws.ops"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  bucket = "${local.application}-codepipeline-artifacts"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = "${aws_kms_key.ops_s3_kms_key.arn}"
        sse_algorithm     = "aws:kms"
      }
    }
  }

  tags = "${merge(
    local.required_tags,
    map(
      "Environment", "ops",
    )
  )}"
}

resource "aws_iam_role" "codepipeline_role" {
  provider = "aws.ops"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-codepipeline-role"

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
    },
    {
      "Effect": "Allow",
      "Resource": "arn:aws:iam::${aws_organizations_account.dev.id}:role/${aws_iam_role.dev_codecommit_access_role.name}",
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

resource "aws_iam_role_policy" "codepipeline_policy" {
  provider = "aws.ops"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-codepipeline-policy"
  role = "${aws_iam_role.codepipeline_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning"
      ],
      "Resource": [
        "${aws_s3_bucket.codepipeline_artifact_bucket.arn}",
        "${aws_s3_bucket.codepipeline_artifact_bucket.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
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

resource "aws_iam_role" "codebuild_role" {
  provider = "aws.ops"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-codebuild-role"

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

resource "aws_iam_role_policy" "codebuild_policy" {
  provider = "aws.ops"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-codebuild-policy"
  role = "${aws_iam_role.codebuild_role.id}"

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
        "${aws_s3_bucket.codepipeline_artifact_bucket.arn}",
        "${aws_s3_bucket.codepipeline_artifact_bucket.arn}/*"
      ],
      "Effect": "Allow"
    },
    {
      "Action": [
        "codebuild:*"
      ],
      "Resource": [
        "${aws_codebuild_project.dev_provision.id}",
        "${aws_codebuild_project.git_merge_dev_to_staging.id}",
        "${aws_codebuild_project.staging_provision.id}",
        "${aws_codebuild_project.git_merge_staging_to_master.id}",
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
        "${aws_kms_key.ops_s3_kms_key.arn}"
        ],
      "Effect": "Allow"
    },
    {
      "Action": [
        "sns:Publish"
      ],
      "Resource": "${aws_sns_topic.ops_sns_topic.arn}",
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

resource "aws_codebuild_project" "dev_provision" {
  provider = "aws.ops"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-dev-provision"
  build_timeout = "${var.codebuild_timeout}"
  # Should this role be a role in the child accounts like the CodeCommit access role in dev?
  service_role = "${aws_iam_role.codebuild_role.arn}"
  encryption_key = "${aws_kms_key.ops_s3_kms_key.arn}"

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
      "Environment", "ops",
    )
  )}"
}

resource "aws_codebuild_project" "git_merge_dev_to_staging" {
  provider = "aws.ops"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-git-merge-dev-to-staging"
  build_timeout = "${var.codebuild_timeout}"
  service_role = "${aws_iam_role.codebuild_role.arn}"
  encryption_key = "${aws_kms_key.ops_s3_kms_key.arn}"

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
      "Environment", "ops",
    )
  )}"
}

resource "aws_codebuild_project" "staging_provision" {
  provider = "aws.ops"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-staging-provision"
  build_timeout = "${var.codebuild_timeout}"
  service_role = "${aws_iam_role.codebuild_role.arn}"
  encryption_key = "${aws_kms_key.ops_s3_kms_key.arn}"

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
      - terraform init -backend=true -backend-config="bucket=${aws_s3_bucket.staging_terraform_state_bucket.id}" -backend-config="key=${var.terraform_state_file}" -backend-config="region=${var.region}" -no-color
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

resource "aws_codebuild_project" "git_merge_staging_to_master" {
  provider = "aws.ops"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-git-merge-staging-to-master"
  build_timeout = "${var.codebuild_timeout}"
  service_role = "${aws_iam_role.codebuild_role.arn}"
  encryption_key = "${aws_kms_key.ops_s3_kms_key.arn}"

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
      - git checkout master
      - git merge origin/staging
      - git push -u origin master
BUILDSPEC
  }

  tags = "${merge(
    local.required_tags,
    map(
      "Environment", "ops",
    )
  )}"
}

resource "aws_codebuild_project" "prod_provision" {
  provider = "aws.ops"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name = "${var.tag_application_id}-prod-provision"
  build_timeout = "${var.codebuild_timeout}"
  service_role = "${aws_iam_role.codebuild_role.arn}"
  encryption_key = "${aws_kms_key.ops_s3_kms_key.arn}"

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
      - terraform init -backend=true -backend-config="bucket=${aws_s3_bucket.prod_terraform_state_bucket.id}" -backend-config="key=${var.terraform_state_file}" -backend-config="region=${var.region}" -no-color
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

# TODO: Add parameters to the repo activity below to make it configurable with other git repos
# TODO: Provide optional flag to tear down Dev Terraform with a boolean (terraform destroy stage)
resource "aws_codepipeline" "dev_codepipeline" {
  provider = "aws.ops"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name     = "${var.tag_application_id}-dev"
  role_arn = "${aws_iam_role.codepipeline_role.arn}"

  artifact_store {
    location = "${aws_s3_bucket.codepipeline_artifact_bucket.bucket}"
    type = "S3"

    encryption_key {
      id = "${aws_kms_alias.ops_s3_kms_key_name.arn}"
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["${var.tag_application_id}-dev-artifacts"]
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
        NotificationArn = "${aws_sns_topic.ops_sns_topic.arn}"
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
        input_artifacts = ["${var.tag_application_id}-dev-artifacts"]
        version         = "1"

        configuration {
          ProjectName = "${var.tag_application_id}-git-merge-dev-to-staging"
        }
    }
  }

  # tags = "${merge(
  #   local.required_tags,
  #   map(
  #     "Environment", "ops",
  #   )
  # )}"

}

# TODO: Add parameters to the repo activity below to make it configurable with other git repos
# TODO: Provide optional flag to tear down Dev Terraform with a boolean (terraform destroy stage)
resource "aws_codepipeline" "staging_codepipeline" {
  provider = "aws.ops"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name     = "${var.tag_application_id}-dev"
  role_arn = "${aws_iam_role.codepipeline_role.arn}"

  artifact_store {
    location = "${aws_s3_bucket.codepipeline_artifact_bucket.bucket}"
    type = "S3"

    encryption_key {
      id = "${aws_kms_alias.ops_s3_kms_key_name.arn}"
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["${var.tag_application_id}-staging-artifacts"]
      role_arn = "${aws_iam_role.dev_codecommit_access_role.arn}"

      configuration {
        RepositoryName = "${aws_codecommit_repository.default_codecommit_repo.repository_name}"
        BranchName = "staging"
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
      input_artifacts = ["${var.tag_application_id}-staging-artifacts-from-source"]
      version         = "1"

      configuration {
        ProjectName = "${var.tag_application_id}-staging-provision"
      }
    }
  }

  stage {
    name = "Staging-Approval"

    action {
      name            = "Approval"
      category        = "Approval"
      owner           = "AWS"
      provider        = "Manual"
      version         = "1"

      configuration {
        NotificationArn = "${aws_sns_topic.ops_sns_topic.arn}"
        # CustomData = "${var.staging_approve_comment}"
        CustomData = "Please approve changes in the staging environment so it can be promoted to staging."
        # ExternalEntityLink = "${var.staging_application_external_url}"
      }
    }
  }

    stage {
      name = "Git-Merge-Staging-To-Master"

      action {
        name            = "Git-Merge-Staging-To-Master"
        category        = "Build"
        owner           = "AWS"
        provider        = "CodeBuild"
        input_artifacts = ["${var.tag_application_id}-staging-artifacts"]
        version         = "1"

        configuration {
          ProjectName = "${var.tag_application_id}-git-merge-staging-to-master"
        }
    }
  }

  # tags = "${merge(
  #   local.required_tags,
  #   map(
  #     "Environment", "ops",
  #   )
  # )}"

}

# TODO: Add parameters to the repo activity below to make it configurable with other git repos
# TODO: Provide optional flag to tear down Dev Terraform with a boolean (terraform destroy stage)
resource "aws_codepipeline" "prod_codepipeline" {
  provider = "aws.ops"
  count = "${var.create_pipelines == "true" ? 1 : 0 }"
  name     = "${var.tag_application_id}-prod"
  role_arn = "${aws_iam_role.codepipeline_role.arn}"

  artifact_store {
    location = "${aws_s3_bucket.codepipeline_artifact_bucket.bucket}"
    type = "S3"

    encryption_key {
      id = "${aws_kms_alias.ops_s3_kms_key_name.arn}"
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["${var.tag_application_id}-prod-artifacts"]
      role_arn = "${aws_iam_role.dev_codecommit_access_role.arn}"

      configuration {
        RepositoryName = "${aws_codecommit_repository.default_codecommit_repo.repository_name}"
        BranchName = "master"
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
      input_artifacts = ["${var.tag_application_id}-prod-artifacts-from-source"]
      version         = "1"

      configuration {
        ProjectName = "${var.tag_application_id}-prod-provision"
      }
    }
  }

  # tags = "${merge(
  #   local.required_tags,
  #   map(
  #     "Environment", "ops",
  #   )
  # )}"

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
