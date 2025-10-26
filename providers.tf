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

provider "kubernetes" {
  #load_config_file = false

  host                   = data.yandex_kubernetes_cluster.cluster.master[0].external_v4_endpoint
  cluster_ca_certificate = data.yandex_kubernetes_cluster.cluster.master[0].cluster_ca_certificate
  token                  = data.yandex_client_config.client.iam_token
}
