resource "yandex_storage_bucket" "images-bucket" {
  bucket = "playful-jarring.images"
  max_size = 10 * pow(1024, 3) # GiB
  default_storage_class = "STANDARD"

  anonymous_access_flags {
    read = true
  }
}

resource "yandex_storage_object" "talos-image" {
  bucket = yandex_storage_bucket.images-bucket.id
  key    = "talos-v1.11.0-amd64"
  source = "../metal-amd64.iso"
}

resource "yandex_compute_image" "talos-image" {
  name       = "talos"
  source_url = "https://storage.yandexcloud.net/${yandex_storage_bucket.images-bucket.bucket}/${yandex_storage_object.talos-image.key}"
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
    description = "talos"
    port = 50000
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Permit ANY"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol          = "ANY"
    description       = "Permit ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol          = "ANY"
    description       = "Allow outgoing traffic to members of the same security group"
    predefined_target = "self_security_group"
  }
}

variable "nodes" {
  type    = set(string)
  default = ["node-0", "node-1", "server"]
}
variable "domain" {
  type    = string
  default = ".k8s.local"
}

resource "yandex_compute_disk" "k8s-node-boot-disks" {
  for_each = var.nodes
  name     = "k8s-boot-disk-${each.key}"
  type     = "network-ssd"
  size     = "20"
  image_id = yandex_compute_image.talos-image.id
}

resource "yandex_compute_instance" "k8s-node-vms" {
  for_each = var.nodes
  name = "k8s-${each.key}"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    disk_id = yandex_compute_disk.k8s-node-boot-disks[each.key].id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.k8s-subnet.id
    nat       = true
    security_group_ids = [ yandex_vpc_security_group.k8s-sg.id ]
  }

  scheduling_policy {
    preemptible = true
  }

}


resource "yandex_vpc_address" "lb-address" {
  name = "lb-address"

  external_ipv4_address {
    zone_id = "ru-central1-a"
  }
}

resource "yandex_cm_certificate" "lb-cert" {
  name    = "lb-cert"
  domains = [local.lb_domain]

  managed {
    challenge_type = "HTTP"
  }
}

resource "yandex_alb_http_router" "main-router" {
  name = "main-router"
}

resource "yandex_alb_virtual_host" "main-vhost" {
  name           = "vhost"
  http_router_id = yandex_alb_http_router.main-router.id
  route {
    name = "acme-challenge"
    http_route {
      http_match {
        path {
          prefix = "/.well-known/acme-challenge/"
        }
      }
      redirect_action {
        replace_scheme = "https"
        replace_host = "validation.certificate-manager.api.cloud.yandex.net"
        replace_prefix = "/${yandex_cm_certificate.lb-cert.id}/"
        response_code = "moved_permanently"
      }
    }
  }
  #route {
  #  name = "kubernetes"
  #  grpc_route {
  #    
  #  }
  #}
}

resource "yandex_alb_load_balancer" "k8s-lb" {
  name = "my-load-balancer"

  network_id = yandex_vpc_network.k8s-network.id
  security_group_ids = [ yandex_vpc_security_group.k8s-sg.id ]

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.k8s-subnet.id
    }
  }

  listener {
    name = "http-listener"
    endpoint {
      address {
        external_ipv4_address {
          address = yandex_vpc_address.lb-address.external_ipv4_address[0].address
        }
      }
      ports = [80]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.main-router.id
        http2_options { }
      }
    }
  }
  listener {
    name = "https-listener"
    endpoint {
      address {
        external_ipv4_address {
          address = yandex_vpc_address.lb-address.external_ipv4_address[0].address
        }
      }
      ports = [443]
    }
    tls {
      default_handler {
        http_handler {
          http_router_id = yandex_alb_http_router.main-router.id
          http2_options { }
        }
        certificate_ids = [yandex_cm_certificate.lb-cert.id]
      }
    }
  }
  listener {
    name = "k8s-listener"
    endpoint {
      address {
        external_ipv4_address {
          address = yandex_vpc_address.lb-address.external_ipv4_address[0].address
        }
      }
      ports = [6443]
    }
    stream {
      handler {
        backend_group_id = yandex_alb_backend_group.lb-backend-group.id
      }
    }
  }
}

resource "yandex_alb_target_group" "lb-k8s-target-group" {
  name = "my-target-group"

  dynamic "target" {
    for_each = local.internal_ip_addresses
    content {
      subnet_id  = yandex_vpc_subnet.k8s-subnet.id
      ip_address = target.value
    }
  }
}

resource "yandex_alb_backend_group" "lb-backend-group" {
  name = "main-backend-group"

  session_affinity {
    connection {
      source_ip = true
    }
  }

  stream_backend {
    name             = "k8s-control"
    weight           = 1
    port             = 6443
    target_group_ids = [yandex_alb_target_group.lb-k8s-target-group.id]
    load_balancing_config {
      panic_threshold = 50
    }
    healthcheck {
      timeout  = "1s"
      interval = "1s"
      http_healthcheck {
        path = "/"
      }
    }
  }
}

locals {
  lb_domain = "${yandex_vpc_address.lb-address.external_ipv4_address[0].address}.sslip.io"
  internal_ip_addresses = {
    for node in var.nodes : node => yandex_compute_instance.k8s-node-vms[node].network_interface.0.ip_address
  }

  external_ip_addresses = {
    for node in var.nodes : node => yandex_compute_instance.k8s-node-vms[node].network_interface.0.nat_ip_address
  }
}

output "internal_ip_addresses" {
   value = local.internal_ip_addresses 
}
output "external_ip_addresses" {
   value = local.external_ip_addresses 
}

resource "local_file" "hosts" {
  filename = "hosts"
  content = <<EOT
%{ for host, ip in local.external_ip_addresses ~}
${ip} ${host}${var.domain} ${host}
%{ endfor ~}
EOT
}
