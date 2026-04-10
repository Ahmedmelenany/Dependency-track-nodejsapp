resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Environment = var.environment
  }
}

resource "aws_db_instance" "postgres" {
  identifier                = "${var.project_name}-postgres"
  engine                    = "postgres"
  engine_version            = "17"
  instance_class            = var.db_instance_class
  allocated_storage         = 20
  max_allocated_storage     = 100
  storage_encrypted         = true
  db_name                   = var.db_name
  username                  = var.db_username
  password                  = var.db_password
  db_subnet_group_name      = aws_db_subnet_group.main.name
  vpc_security_group_ids    = [aws_security_group.rds.id]
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-postgres-final"
  deletion_protection       = true
  multi_az                  = false

  tags = {
    Name        = "${var.project_name}-postgres"
    Environment = var.environment
  }
}
