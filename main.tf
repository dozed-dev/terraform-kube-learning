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

//
// Create KMS Symmetric Key.
//
resource "yandex_kms_symmetric_key" "k8s-key" {
  name              = "k8s-key"
  description       = "k8s"
  default_algorithm = "AES_128"
  rotation_period   = "8760h" // equal to 1 year
}
//
// Create a new Logging Group.
//
resource "yandex_logging_group" "k8s-logger" {
  name      = "k8s-logger"
}
//
// Create a new Managed Kubernetes zonal Cluster.
//
resource "yandex_kubernetes_cluster" "k8s-cluster" {
  name        = "k8s-cluster"

  network_id = yandex_vpc_network.k8s-network.id

  master {
    version = "1.32"
    zonal {
      zone      = yandex_vpc_subnet.k8s-subnet.zone
      subnet_id = yandex_vpc_subnet.k8s-subnet.id
    }

    public_ip = true

    security_group_ids = ["${yandex_vpc_security_group.k8s-sg.id}"]

    master_logging {
      enabled                    = true
      log_group_id               = yandex_logging_group.k8s-logger.id
      kube_apiserver_enabled     = true
      cluster_autoscaler_enabled = true
      events_enabled             = true
      audit_enabled              = true
    }
  }

  service_account_id      = "ajenisg7i6s31don9ch2"
  node_service_account_id = "ajenisg7i6s31don9ch2"

  kms_provider {
    key_id = yandex_kms_symmetric_key.k8s-key.id
  }
}

//
// Create a new Managed Kubernetes Node Group.
//
resource "yandex_kubernetes_node_group" "k8s-cluster-nodes" {
  cluster_id  = yandex_kubernetes_cluster.k8s-cluster.id
  version     = "1.32"

  instance_template {
    platform_id = "standard-v2"

    network_interface {
      nat        = true
      subnet_ids = ["${yandex_vpc_subnet.k8s-subnet.id}"]
    }

    resources {
      memory = 2
      cores  = 2
    }

    boot_disk {
      type = "network-ssd"
      size = 30 // minimum size
    }

    scheduling_policy {
      preemptible = true
    }

    container_runtime {
      type = "containerd"
    }
  }

  scale_policy {
    auto_scale {
      initial = 1
      min = 0
      max = 4
    }
  }

  allocation_policy {
    location {
      zone = yandex_vpc_subnet.k8s-subnet.zone
    }
  }

  maintenance_policy {
    auto_upgrade = true
    auto_repair  = true

    maintenance_window {
      day        = "monday"
      start_time = "15:00"
      duration   = "3h"
    }

    maintenance_window {
      day        = "friday"
      start_time = "10:00"
      duration   = "4h30m"
    }
  }
}

resource "local_file" "kubeconfig" {
  filename = "k8s/kubeconfig"
  file_permission = "0644"
  content  = templatefile("${path.module}/kubeconfig.tftpl", {
    base64cert = base64encode(yandex_kubernetes_cluster.k8s-cluster.master[0].cluster_ca_certificate)
    master_ip = yandex_kubernetes_cluster.k8s-cluster.master[0].external_v4_address
    cluster_id = yandex_kubernetes_cluster.k8s-cluster.id
  })
}
