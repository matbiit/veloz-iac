variable "ambiente" {
  type = string
}

variable "replicas_vitrine" {
  type    = number
  default = 1
}

variable "porta_base" {
  description = "Primeira porta no host para a vitrine"
  type        = number
  default     = 8080
}

variable "memoria_vitrine_mb" {
  type    = number
  default = 128
}

variable "imagem_vitrine" {
  type    = string
  default = "nginx:1.27-alpine"
}

variable "imagem_cache" {
  type    = string
  default = "redis:7.4-alpine"
}
