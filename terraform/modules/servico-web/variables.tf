variable "nome" {
  description = "Nome lógico do serviço (ex.: vitrine, carrinho, cache)"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.nome))
    error_message = "Use letras minúsculas, números e hífen (3 a 21 caracteres)."
  }
}

variable "ambiente" {
  description = "dev | hml | prod | blackfriday"
  type        = string
  validation {
    condition     = contains(["dev", "hml", "prod", "blackfriday"], var.ambiente)
    error_message = "Ambiente deve ser dev, hml, prod ou blackfriday."
  }
}

variable "imagem" {
  description = "Imagem do container (sempre com tag fixa; 'latest' é proibido)"
  type        = string
  validation {
    condition     = !endswith(var.imagem, ":latest") && strcontains(var.imagem, ":")
    error_message = "Fixe a versão da imagem (ex.: nginx:1.27-alpine). 'latest' gera drift entre ambientes."
  }
}

variable "replicas" {
  description = "Quantidade de containers"
  type        = number
  default     = 1
  validation {
    condition     = var.replicas >= 1 && var.replicas <= 10
    error_message = "Entre 1 e 10 réplicas."
  }
}

variable "rede" {
  description = "Nome da rede Docker compartilhada"
  type        = string
}

variable "porta_interna" {
  type    = number
  default = 80
}

variable "porta_externa_base" {
  description = "Primeira porta publicada no host (réplica N usa base+N). null = não publica (ex.: cache interno)"
  type        = number
  default     = null
}

variable "memoria_mb" {
  type    = number
  default = 128
}

variable "variaveis" {
  description = "Variáveis de ambiente (NUNCA coloque segredos aqui; use um cofre/secret manager)"
  type        = map(string)
  default     = {}
}

variable "owner" {
  description = "Squad dono do serviço (obrigatório - FinOps e incidentes)"
  type        = string
}

variable "cost_center" {
  description = "Centro de custo (obrigatório - FinOps)"
  type        = string
}
