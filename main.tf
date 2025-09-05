terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  # https://github.com/yandex-cloud-examples/yc-terraform-state
  backend "s3" {
    endpoint = "storage.yandexcloud.net"
    use_lockfile = true
    bucket = "playful-jarring.tf-state"
    region = "ru-central1"
    key = "terraform/terraform.tfstate"

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true # Необходимая опция Terraform для версии 1.6.1 и старше.
    skip_s3_checksum            = true # Необходимая опция при описании бэкенда для Terraform версии 1.6.3 и старше.
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  zone = "ru-central1-a"
}

resource "yandex_vpc_network" "k8s-network" {
  name = "k8s-tf-network"
}

resource "yandex_vpc_subnet" "k8s-subnet" {
  name           = "subnet1"
  network_id     = yandex_vpc_network.k8s-network.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "yandex_vpc_security_group" "k8s-sg" {
  name = "k8s-sg"
  network_id = yandex_vpc_network.k8s-network.id

  ingress {
    protocol = "TCP"
    description = "ssh"
    port = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Permit ANY"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol          = "ANY"
    description       = "Allow incoming traffic from members of the same security group"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }

  egress {
    protocol          = "ANY"
    description       = "Allow outgoing traffic to members of the same security group"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }
}

variable "node_count" {
  type    = number
  default = 3
}

# debian-12 image: fd8j3nge575bu7csn9sa
# https://yandex.cloud/ru/marketplace/products/yc/debian-12
resource "yandex_compute_disk" "k8s-node-boot-disks" {
  count    = var.node_count
  name     = "k8s-node-boot-disk-${count.index}"
  type     = "network-ssd"
  size     = "20"
  image_id = "fd8j3nge575bu7csn9sa"
}

resource "yandex_compute_instance" "k8s-node-vms" {
  count = var.node_count
  name = "k8s-node-${count.index}"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    disk_id = yandex_compute_disk.k8s-node-boot-disks[count.index].id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.k8s-subnet.id
    nat       = true
    security_group_ids = [ yandex_vpc_security_group.k8s-sg.id ]
  }

  scheduling_policy {
    preemptible = true
  }

  # https://yandex.cloud/ru/docs/compute/concepts/vm-metadata
  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }
}

output "internal_ip_addresses" {
   value = [for x in yandex_compute_instance.k8s-node-vms : x.network_interface.0.ip_address]
}

output "external_ip_addresses" {
   value = [for x in yandex_compute_instance.k8s-node-vms : x.network_interface.0.nat_ip_address]
}
