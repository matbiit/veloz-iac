output "vitrine_urls" {
  value = module.vitrine.urls
}

output "containers" {
  value = concat(module.vitrine.containers, module.cache.containers)
}
