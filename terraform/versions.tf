terraform {
  required_version = ">= 1.6" # funciona com Terraform >= 1.6 ou OpenTofu >= 1.6

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.6"
    }
  }
}

provider "docker" {
  # Docker Desktop / Codespaces / Linux. No Windows sem WSL use: "npipe:////.//pipe//docker_engine"
  host = "unix:///var/run/docker.sock"
}
