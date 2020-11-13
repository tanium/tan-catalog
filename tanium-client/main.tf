resource "null_resource" "linux_client" {
  connection {
    type = "ssh"
    host = var.client_ipv4_address
    user = var.user
    password = var.pass
    private_key = var.private_key
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install-tanium-client.sh"
    destination = "/tmp/install-tanium-client.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "cd /tmp",
      "bash /tmp/install-tanium-client.sh --tanium-server ${var.server_ipv4_address} --apikey ${var.cos_bucket_apikey} --tanium-client-files-folder ${var.tanium_client_files_folder} --cos-bucket-public-endpoint ${var.cos_bucket_public_endpoint}"
    ]
  }
}
