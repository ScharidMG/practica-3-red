# outputs.tf
output "red" {
  value       = google_compute_network.vpc.name
  description = "Nombre de la VPC creada"
}

output "subred_publica" {
  value       = google_compute_subnetwork.publica.self_link
  description = "Identificador completo de la subred de aplicación"
}

output "ip_publica_app" {
  value       = google_compute_instance.app.network_interface[0].access_config[0].nat_ip
  description = "Dirección IP pública de la aplicación"
}