# Lets GitHub Actions workflows in this repo assume an AWS role without stored keys.
# Applied once, locally, by an admin. Used by .github/workflows/test-deploy.yml.
# https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services

locals {
  # The repo uses GitHub's immutable OIDC subject format, which includes the owner and
  # repo IDs so a renamed or re-created repo with the same name can't match.
  #   gh api repos/BrianHenryIE/rearc-quest/actions/oidc/customization/sub
  subject_prefix = "repo:BrianHenryIE@4720401/rearc-quest@1443627512"
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Only pull_request runs and manual runs (workflow_dispatch on a branch) from this repo.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "${local.subject_prefix}:pull_request",
        "${local.subject_prefix}:ref:refs/heads/*",
      ]
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
resource "aws_iam_role" "ci_deploy" {
  name               = "rearc-quest-github-ci-deploy"
  description        = "GitHub Actions: deploy, test and destroy throwaway rearc-quest EC2 instances"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

# Least privilege for 2-terraform-ec2 in a CI workspace.
# Anything that changes or deletes an existing resource requires the Environment=ci tag,
# which 2-terraform-ec2 sets only outside the default (production) workspace.
data "aws_iam_policy_document" "ci_deploy" {
  statement {
    sid       = "Read"
    actions   = ["ec2:Describe*"]
    resources = ["*"]
  }

  statement {
    sid       = "ReadAmiParameter"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = ["arn:aws:ssm:*::parameter/aws/service/ami-amazon-linux-latest/*"]
  }

  statement {
    sid       = "Create"
    actions   = ["ec2:RunInstances", "ec2:CreateSecurityGroup"]
    resources = ["*"]
  }

  # Tags may only be written as part of creating a resource, never added to existing ones.
  statement {
    sid       = "TagOnCreate"
    actions   = ["ec2:CreateTags"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["RunInstances", "CreateSecurityGroup"]
    }
  }

  statement {
    sid = "ModifyAndDeleteCiOnly"
    actions = [
      "ec2:TerminateInstances",
      "ec2:StopInstances",
      "ec2:ModifyInstanceAttribute",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Environment"
      values   = ["ci"]
    }
  }
}

resource "aws_iam_role_policy" "ci_deploy" {
  name   = "ci-deploy"
  role   = aws_iam_role.ci_deploy.id
  policy = data.aws_iam_policy_document.ci_deploy.json
}

output "role_arn" {
  description = "Set as role-to-assume in .github/workflows/test-deploy.yml"
  value       = aws_iam_role.ci_deploy.arn
}
