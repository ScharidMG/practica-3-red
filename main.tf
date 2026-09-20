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

# ---------------------------------------------------------------- RED
# La VPC es global. En modo personalizado nace sin subredes.
resource "google_compute_network" "vpc" {
  name                    = "${var.prefijo}-vpc"
  auto_create_subnetworks = false
}

# La subred sí es regional, y es donde las máquinas toman su IP interna.
resource "google_compute_subnetwork" "publica" {
  name          = "${var.prefijo}-sub-publica"
  ip_cidr_range = var.cidr_publica # 10.10.1.0/24
  region        = var.region
  network       = google_compute_network.vpc.id
}

resource "google_compute_subnetwork" "privada" {
  name          = "${var.prefijo}-sub-privada"
  ip_cidr_range = var.cidr_privada # 10.10.2.0/24
  region        = var.region
  network       = google_compute_network.vpc.id
}

# --------------------------------------------- SALIDA SIN ENTRADA (NAT)
resource "google_compute_router" "router" {
  name    = "${var.prefijo}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

# Solo la subred privada sale por el NAT. La pública ya tiene IP externa.
resource "google_compute_router_nat" "nat" {
  name                               = "${var.prefijo}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.privada.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# ------------------------------------------------------- MAQUINAS
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
    access_config {} # IP pública efímera
  }

  # Al leer la IP de "datos" aquí, Terraform ya sabe que datos se crea primero.
  metadata_startup_script = templatefile("${path.module}/arranque.sh.tftpl", {
    ip_datos       = google_compute_instance.datos.network_interface[0].network_ip
    identificacion = var.identificacion
  })
}

resource "google_compute_instance" "datos" {
  name         = "${var.prefijo}-datos"
  machine_type = var.tipo_maquina
  zone         = var.zona
  tags         = ["servidor-datos"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.privada.id
    # sin access_config: sin IP publica, no alcanzable desde internet
  }

  metadata_startup_script = templatefile("${path.module}/arranque_datos.sh.tftpl", {
    identificacion = var.identificacion
  })

  # Esta dependencia NO aparece en ninguna referencia del código, pero existe:
  # sin NAT, el script de arranque no puede instalar nginx.
  depends_on = [google_compute_router_nat.nat]
}

# ------------------------------------------------------ CORTAFUEGOS
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

resource "google_compute_firewall" "app_a_datos" {
  name    = "${var.prefijo}-permitir-app-a-datos"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_tags = ["servidor-web"] # solo desde la app, no desde toda la red
  target_tags = ["servidor-datos"]
}