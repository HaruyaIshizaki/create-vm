terraform {
  # terraformのversionを固定する
  required_version = ">=1.6.0"
  # プロバイダのversionを固定する
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.13.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_compute_network" "vpc_network" {
  project                 = var.project_id
  name                    = "vm-net"
  auto_create_subnetworks = false
}

# サブネットを作成すると自動でゲートウェイとルートを設定してくれるので、サブネットの設定のみ
resource "google_compute_subnetwork" "vpc_subnetwork" {
  name   = "vm-subnet"
  region = var.region

  network       = google_compute_network.vpc_network.self_link
  ip_cidr_range = "10.0.0.0/24"

  # Flowlogを有効化する
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
    # ログの取得間隔
    aggregation_interval = "INTERVAL_10_MIN"
    # トラっフィクのサンプリング率
    flow_sampling = 0.5
  }
}

# 外部IPを持たないVMを作成する
resource "google_compute_instance" "default" {
  project = var.project_id
  name = "test01"
  zone = var.zone
  machine_type = "e2-medium"
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }
  network_interface {
    network    = "custom-network1"
    subnetwork = google_compute_subnetwork.vpc_subnetwork.self_link
  }
}

# tcpプロトコルでVPC内部での通信を許可するFWのルールを設定
resource "google_compute_firewall" "rules" {
    project = var.project_id
    name = "allow-ssh"
    network = google_compute_network.vpc_network.self_link

  allow {
    protocol = "tcp"
    ports = ["22"]
  }
  source_ranges = ["10.0.0.0/24"]
}