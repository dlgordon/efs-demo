data "aws_ami" "amazon-linux-2" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

data "aws_iam_policy_document" "efs_host_policy" {
  statement {
    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite"
    ]
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

  statement {
    actions = [
      "elasticfilesystem:Describe*",
      "ec2:DescribeAvailabilityZones"
    ]
    effect    = "Allow"
    resources = ["*"]

  }
}

resource "aws_iam_policy" "efs_host_policy_policy" {
  name_prefix = "efs_host_policy_"
  path        = "/"
  description = "Enabled SSM and Session Logging"

  policy = data.aws_iam_policy_document.efs_host_policy.json
}

resource "aws_iam_role" "host_role_with_efs" {
  name_prefix = "efs_host_role_efs_"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm-resources-ssm-policy" {
  role       = aws_iam_role.host_role_with_efs.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy_attachment" "efs-resources-ssm-policy" {
  role       = aws_iam_role.host_role_with_efs.name
  policy_arn = aws_iam_policy.efs_host_policy_policy.arn
}


resource "aws_iam_instance_profile" "host_role_with_efs_instanceprofile" {
  name = "host_role_with_efs_instanceprofile"
  role = aws_iam_role.host_role_with_efs.name
}

resource "aws_iam_role" "host_role_without_efs" {
  name_prefix = "efs_host_role_noefs_"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dev-resources-ssm-policy" {
  role       = aws_iam_role.host_role_without_efs.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "host_role_without_efs_instanceprofile" {
  name = "host_role_without_efs_instanceprofile"
  role = aws_iam_role.host_role_without_efs.name
}

# Instance allowed to mount due to being in the same security group and having an iam role to use the accesspoint
resource "aws_instance" "success" {
  ami                         = data.aws_ami.amazon-linux-2.id
  associate_public_ip_address = true
  instance_type               = "t3.micro"
  iam_instance_profile        = aws_iam_instance_profile.host_role_with_efs_instanceprofile.id
  subnet_id                   = aws_subnet.core_subnet_a.id
  vpc_security_group_ids      = [aws_security_group.demo_efs_securitygroup.id]
  tags = {
    "Name" = "efs"
  }
}

# Instance not allowed to mount due to security group issue
resource "aws_instance" "fail_security_group" {
  ami                         = data.aws_ami.amazon-linux-2.id
  associate_public_ip_address = true
  instance_type               = "t3.micro"
  iam_instance_profile        = aws_iam_instance_profile.host_role_with_efs_instanceprofile.id
  subnet_id                   = aws_subnet.core_subnet_a.id
  tags = {
    "Name" = "no-sg"
  }
}


# Instance not allowed to mount due to not being able to access the access point
resource "aws_instance" "fail_iam_role" {
  ami                         = data.aws_ami.amazon-linux-2.id
  associate_public_ip_address = true
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.core_subnet_a.id
  iam_instance_profile        = aws_iam_instance_profile.host_role_without_efs_instanceprofile.id
  vpc_security_group_ids      = [aws_security_group.demo_efs_securitygroup.id]
  tags = {
    "Name" = "no-iam"
  }
}
