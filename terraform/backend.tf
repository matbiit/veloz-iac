# ESTADO REMOTO - como fazer em produção (caso Axion Data: tfstate trocado por e-mail e corrompido 2x).
#
# Na aula usamos o backend local (padrão) para não depender de conta em nuvem.
# Em produção, descomente o bloco abaixo. Desde o Terraform 1.10 o backend S3 faz
# bloqueio (lock) nativo com `use_lockfile = true`, sem precisar de tabela DynamoDB.
#
# terraform {
#   backend "s3" {
#     bucket       = "veloz-terraform-state"
#     key          = "plataforma/vitrine/terraform.tfstate"
#     region       = "sa-east-1"
#     encrypt      = true         # estado pode conter dados sensíveis
#     use_lockfile = true         # impede dois `apply` simultâneos
#   }
# }
#
# Alternativas equivalentes: azurerm (Blob + lease), gcs (lock nativo),
# HCP Terraform / Spacelift / env0 (estado + lock + histórico + RBAC).
