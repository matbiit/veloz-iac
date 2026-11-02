# Ambiente da loja VeloZ: vitrine (frontend) + cache.
# O MESMO código cria dev, hml ou o ambiente de Black Friday - só muda o .tfvars.

resource "docker_network" "loja" {
  name = "${var.ambiente}-veloz-rede"
}

module "vitrine" {
  source = "./modules/servico-web"

  nome               = "vitrine"
  ambiente           = var.ambiente
  imagem             = var.imagem_vitrine
  replicas           = var.replicas_vitrine
  rede               = docker_network.loja.name
  porta_externa_base = var.porta_base
  memoria_mb         = var.memoria_vitrine_mb
  owner              = "squad-vitrine"
  cost_center        = "CC-1020-ECOMMERCE"
  variaveis = {
    AMBIENTE   = var.ambiente
    CACHE_HOST = "${var.ambiente}-cache-0"
  }
}

module "cache" {
  source = "./modules/servico-web"

  nome          = "cache"
  ambiente      = var.ambiente
  imagem        = var.imagem_cache
  replicas      = 1
  rede          = docker_network.loja.name
  porta_interna = 6379 # sem porta_externa_base: o cache NÃO fica exposto no host
  memoria_mb    = 256
  owner         = "squad-plataforma"
  cost_center   = "CC-1001-PLATAFORMA"
}
