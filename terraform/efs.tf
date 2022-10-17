resource "aws_efs_file_system" "demo_efs" {
}

resource "aws_efs_access_point" "demo_efs_accesspoint" {
  file_system_id = aws_efs_file_system.demo_efs.id
}

resource "aws_efs_file_system_policy" "demo_efs_policy" {
  file_system_id                     = aws_efs_file_system.demo_efs.id
  bypass_policy_lockout_safety_check = false
  policy                             = data.aws_iam_policy_document.efs_policy.json
}

resource "aws_security_group" "demo_efs_securitygroup" {
  name        = "allow_mount"
  description = "Allow NFS mount traffic"
  vpc_id      = aws_vpc.core_vpc.id


  ingress {
    description = "TLS from VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    self        = true
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_efs_mount_target" "demo_efs_mount_a" {
  file_system_id  = aws_efs_file_system.demo_efs.id
  subnet_id       = aws_subnet.core_subnet_a.id
  security_groups = [aws_security_group.demo_efs_securitygroup.id]
}
resource "aws_efs_mount_target" "demo_efs_mount_b" {
  file_system_id  = aws_efs_file_system.demo_efs.id
  subnet_id       = aws_subnet.core_subnet_b.id
  security_groups = [aws_security_group.demo_efs_securitygroup.id]
}

data "aws_iam_policy_document" "efs_policy" {
  statement {
    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite"
    ]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.host_role_with_efs.arn]
    }
    effect    = "Allow"
    resources = [aws_efs_file_system.demo_efs.arn]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["true"]
    }
    condition {
      test     = "Bool"
      variable = "elasticfilesystem:AccessedViaMountTarget"
      values   = ["true"]
    }
    condition {
      test     = "StringEquals"
      variable = "elasticfilesystem:AccessPointArn"
      values   = [aws_efs_access_point.demo_efs_accesspoint.arn]
    }

  }
}