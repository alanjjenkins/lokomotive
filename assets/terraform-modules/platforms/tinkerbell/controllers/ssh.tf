# Secure copy etcd TLS assets and kubeconfig to controllers. Activates 'kubelet.service'.
resource "null_resource" "copy-controller-secrets" {
  count = length(var.ip_addresses)

  connection {
    type    = "ssh"
    host    = var.ip_addresses[count.index]
    user    = "core"
    timeout = "60m"
  }

  provisioner "file" {
    content     = module.controller[count.index].bootstrap_kubeconfig
    destination = "$HOME/kubeconfig"
  }

  provisioner "file" {
    content     = module.bootkube.etcd_ca_cert
    destination = "$HOME/etcd-client-ca.crt"
  }

  provisioner "file" {
    content     = module.bootkube.etcd_client_cert
    destination = "$HOME/etcd-client.crt"
  }

  provisioner "file" {
    content     = module.bootkube.etcd_client_key
    destination = "$HOME/etcd-client.key"
  }

  provisioner "file" {
    content     = module.bootkube.etcd_server_cert
    destination = "$HOME/etcd-server.crt"
  }

  provisioner "file" {
    content     = module.bootkube.etcd_server_key
    destination = "$HOME/etcd-server.key"
  }

  provisioner "file" {
    content     = module.bootkube.etcd_peer_cert
    destination = "$HOME/etcd-peer.crt"
  }

  provisioner "file" {
    content     = module.bootkube.etcd_peer_key
    destination = "$HOME/etcd-peer.key"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "sudo mv $HOME/kubeconfig /etc/kubernetes/kubeconfig",
      "sudo chown root:root /etc/kubernetes/kubeconfig",
      "sudo chmod 600 /etc/kubernetes/kubeconfig",
      # Using "etcd/." copies the etcd/ folder recursively in an idempotent
      # way. See https://unix.stackexchange.com/a/228637 for details.
      "[ -d /etc/ssl/etcd ] && sudo cp -R /etc/ssl/etcd/. /etc/ssl/etcd.old && sudo rm -rf /etc/ssl/etcd",
      "sudo mkdir -p /etc/ssl/etcd/etcd",
      "sudo mv etcd-client* /etc/ssl/etcd/",
      "sudo cp /etc/ssl/etcd/etcd-client-ca.crt /etc/ssl/etcd/etcd/server-ca.crt",
      "sudo mv etcd-server.crt /etc/ssl/etcd/etcd/server.crt",
      "sudo mv etcd-server.key /etc/ssl/etcd/etcd/server.key",
      "sudo cp /etc/ssl/etcd/etcd-client-ca.crt /etc/ssl/etcd/etcd/peer-ca.crt",
      "sudo mv etcd-peer.crt /etc/ssl/etcd/etcd/peer.crt",
      "sudo mv etcd-peer.key /etc/ssl/etcd/etcd/peer.key",
      "sudo chown -R etcd:etcd /etc/ssl/etcd",
      "sudo chmod -R 500 /etc/ssl/etcd",
      "sudo systemctl restart etcd",
    ]
  }

  triggers = {
    etcd_ca_cert     = module.bootkube.etcd_ca_cert
    etcd_server_cert = module.bootkube.etcd_server_cert
    etcd_peer_cert   = module.bootkube.etcd_peer_cert
  }
}

# Secure copy bootkube assets to ONE controller and start bootkube to perform
# one-time self-hosted cluster bootstrapping.
resource "null_resource" "bootkube-start" {
  # Without depends_on, this remote-exec may start before the kubeconfig copy.
  # Terraform only does one task at a time, so it would try to bootstrap
  # while no Kubelets are running.
  depends_on = [
    null_resource.copy-controller-secrets,
  ]

  connection {
    type    = "ssh"
    host    = var.ip_addresses[0]
    user    = "core"
    timeout = "15m"
  }

  provisioner "file" {
    source      = var.asset_dir
    destination = "$HOME/assets"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv $HOME/assets /opt/bootkube",
      # Use stdbuf to disable the buffer while printing logs to make sure everything is transmitted back to
      # Terraform before we return error. We should be able to remove it once
      # https://github.com/hashicorp/terraform/issues/27121 is resolved.
      "sudo systemctl start bootkube || (stdbuf -i0 -o0 -e0 sudo journalctl -u bootkube --no-pager; exit 1)",
    ]
  }
}
