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
resource "yandex_kubernetes_cluster" "zonal_cluster" {
  name        = "name"
  description = "description"

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
