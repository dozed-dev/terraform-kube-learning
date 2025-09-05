terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  # https://github.com/yandex-cloud-examples/yc-terraform-state
  backend "s3" {
    endpoints = {
      s3 = "storage.yandexcloud.net"
    }
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
