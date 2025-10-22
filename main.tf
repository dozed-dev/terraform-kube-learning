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

