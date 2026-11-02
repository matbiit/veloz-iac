output "containers" {
  description = "Nomes dos containers criados"
  value       = docker_container.this[*].name
}

output "urls" {
  description = "URLs publicadas no host (vazio se o serviço é interno)"
  value       = var.porta_externa_base == null ? [] : [for i in range(var.replicas) : "http://localhost:${var.porta_externa_base + i}"]
}
