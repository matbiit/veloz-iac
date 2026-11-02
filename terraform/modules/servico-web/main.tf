# Módulo "servico-web" - mantido pelo time de PLATAFORMA da VeloZ.
# Os squads de produto consomem como "caixa-preta": informam nome, imagem e réplicas;
# o módulo garante o padrão da empresa (rede, limites de memória, labels de custo, restart).

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.6"
    }
  }
}

locals {
  prefixo = "${var.ambiente}-${var.nome}"
  labels_obrigatorios = {
    "veloz.owner"       = var.owner
    "veloz.cost_center" = var.cost_center
    "veloz.ambiente"    = var.ambiente
    "veloz.gerenciado"  = "terraform" # quem achar este container sabe: NÃO mexa na mão
  }
}

resource "docker_image" "this" {
  name         = var.imagem
  keep_locally = true
}

resource "docker_container" "this" {
  count       = var.replicas
  name        = "${local.prefixo}-${count.index}"
  image       = docker_image.this.image_id
  restart     = "unless-stopped"
  memory      = var.memoria_mb
  memory_swap = var.memoria_mb # swap desligado: comportamento previsível sob carga
  env         = [for k, v in var.variaveis : "${k}=${v}"]

  networks_advanced {
    name = var.rede
  }

  dynamic "ports" {
    for_each = var.porta_externa_base == null ? [] : [1]
    content {
      internal = var.porta_interna
      external = var.porta_externa_base + count.index
    }
  }

  dynamic "labels" {
    for_each = local.labels_obrigatorios
    content {
      label = labels.key
      value = labels.value
    }
  }
}
