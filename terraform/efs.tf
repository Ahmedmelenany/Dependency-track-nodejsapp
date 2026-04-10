resource "aws_efs_file_system" "dtrack" {
  encrypted = true

  tags = {
    Name        = "${var.project_name}-efs"
    Environment = var.environment
  }
}

resource "aws_efs_mount_target" "dtrack" {
  count           = length(aws_subnet.private)
  file_system_id  = aws_efs_file_system.dtrack.id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_access_point" "dtrack" {
  file_system_id = aws_efs_file_system.dtrack.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/data"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "755"
    }
  }

  tags = {
    Name        = "${var.project_name}-efs-ap"
    Environment = var.environment
  }
}
