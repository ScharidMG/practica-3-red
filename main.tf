# main.tf
terraform {
  required_providers {
    google = { source = "hashicorp/google" }
  }
}

provider "google" {
  project = var.proyecto
  region  = var.region
}

# La VPC es global. En modo personalizado nace sin subredes.
resource "google_compute_network" "vpc" {
  name                    = "${var.prefijo}-vpc"
  auto_create_subnetworks = false
}

# La subred sí es regional, y es donde las máquinas toman su IP interna.
resource "google_compute_subnetwork" "publica" {
  name          = "${var.prefijo}-sub-publica"
  ip_cidr_range = var.cidr_publica
  region        = var.region
  network       = google_compute_network.vpc.id
}


#añadidos 

resource "google_compute_instance" "app" {
  name         = "${var.prefijo}-app"
  machine_type = var.tipo_maquina
  zone         = var.zona
  tags         = ["servidor-web"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.publica.id
    access_config {}
  }

  metadata_startup_script = file("${path.module}/arranque.sh")
}

#masañadidos

resource "google_compute_firewall" "app_http" {
  name    = "${var.prefijo}-permitir-http"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["servidor-web"]
}

resource "google_compute_firewall" "ssh_iap" {
  name    = "${var.prefijo}-permitir-ssh-iap"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # 35.235.240.0/20 es el rango desde el que Google reenvia SSH por IAP
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["servidor-web", "servidor-datos"]
}

