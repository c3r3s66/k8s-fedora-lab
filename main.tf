terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8.0"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_pool" "k8s_pool" {
  name = "k8s_pool"
  type = "dir"
  path = "/tmp/terraform-k8s-pool"
}

resource "libvirt_volume" "fedora_base" {
  name   = "fedora-base.qcow2"
  pool   = libvirt_pool.k8s_pool.name
  source = "https://download.fedoraproject.org/pub/fedora/linux/releases/44/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2"
  format = "qcow2"
}

resource "libvirt_network" "k8s_net" {
  name      = "k8s_net"
  mode      = "nat"
  domain    = "k8s.local"
  addresses = ["192.168.150.0/24"]
  dhcp {
    enabled = true
  }
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name      = "commoninit.iso"
  user_data = templatefile("${path.module}/cloud_init.cfg", {
    ssh_public_key = file("~/.ssh/id_ed25519.pub")
  })
  pool      = libvirt_pool.k8s_pool.name
}

locals {
  nodes = {
    "k8s-master"   = { vcpu = 2, memory = 3072, ip = "192.168.150.10" }
    "k8s-worker-1" = { vcpu = 2, memory = 2048, ip = "192.168.150.11" }
    "k8s-worker-2" = { vcpu = 2, memory = 2048, ip = "192.168.150.12" }
  }
}

resource "libvirt_volume" "node_disk" {
  for_each       = local.nodes
  name           = "${each.key}-disk.qcow2"
  pool           = libvirt_pool.k8s_pool.name
  base_volume_id = libvirt_volume.fedora_base.id
  size           = 21474836480 # 20 GB
}

resource "libvirt_domain" "k8s_node" {
  for_each  = local.nodes
  name      = each.key
  memory    = each.value.memory
  vcpu      = each.value.vcpu
  cloudinit = libvirt_cloudinit_disk.commoninit.id

  network_interface {
    network_name   = libvirt_network.k8s_net.name
    addresses      = [each.value.ip]
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.node_disk[each.key].id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
}
