terraform {
  required_version = ">= 1.6" # funciona com Terraform >= 1.6 ou OpenTofu >= 1.6

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.6"
    }
  }
}

# SEM DOCKER: o Podman expõe uma API compatível com a do Docker (`podman system service`).
# O provider kreuzwerker/docker só fala HTTP com esse socket; nenhum daemon Docker é instalado.
# Suba a API com:  bash scripts/podman-api.sh   (ou, em Linux com systemd: systemctl --user enable --now podman.socket)
provider "docker" {
  host = var.container_host
}
