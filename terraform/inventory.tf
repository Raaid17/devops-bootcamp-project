# Written into ansible/ so the controller picks it up straight from the repo.
resource "local_file" "inventory" {
  filename        = "${path.module}/../ansible/inventory.ini"
  file_permission = "0644"

  content = templatefile("${path.module}/inventory.ini.tftpl", {
    web_id                = module.web.id
    monitoring_id         = module.monitoring.id
    region                = var.region
    transfer_bucket       = aws_s3_bucket.ansible_transfer.id
    web_private_ip        = var.web_private_ip
    monitoring_private_ip = var.monitoring_private_ip
    ecr_image             = "${aws_ecr_repository.app.repository_url}:latest"
  })
}
