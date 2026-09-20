# outputs.tf
output "red" {
  value       = google_compute_network.vpc.name
  description = "Nombre de la VPC creada"
}

output "subred_publica" {
  value       = google_compute_subnetwork.publica.self_link
  description = "Identificador completo de la subred de aplicación"
}