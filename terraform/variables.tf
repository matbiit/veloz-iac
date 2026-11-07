variable "container_host" {
  description = "Socket da API do Podman (rootless: unix:///run/user/<uid>/podman/podman.sock)"
  type        = string
  default     = "unix:///tmp/podman.sock" # o que scripts/podman-api.sh cria
}

variable "limitar_memoria" {
  description = "false em ambientes rootless sem delegação de cgroup v2 (alguns Codespaces/WSL)"
  type        = bool
  default     = true
}

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
  default = "docker.io/library/nginx:1.27-alpine" # nome completo: o Podman não adivinha o registry
}

variable "imagem_cache" {
  type    = string
  default = "docker.io/library/redis:7.4-alpine"
}
