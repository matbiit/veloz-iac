# ============================================================================
# CASO AXION DATA - bucket com dados de clientes
# Este arquivo foi gerado por um assistente de IA a partir do prompt de um dev júnior:
#   "crie um bucket S3 para guardar os exports de clientes e que o dashboard consiga ler"
# Ele É VÁLIDO (terraform validate passa) e FUNCIONA... e é exatamente o tipo de código
# que expôs dados de clientes por dias na Axion Data.
#
# MISSÃO DO GRUPO: rodar checkov + conftest, entender cada falha e corrigir.
# (Não precisa de conta AWS: as ferramentas analisam o código, não a nuvem.)
# ============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "sa-east-1"
}

resource "aws_s3_bucket" "exports_clientes" {
  bucket = "axion-exports-clientes"
}

resource "aws_s3_bucket_public_access_block" "exports_clientes" {
  bucket                  = aws_s3_bucket.exports_clientes.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "exports_clientes" {
  bucket = aws_s3_bucket.exports_clientes.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "exports_clientes" {
  depends_on = [aws_s3_bucket_ownership_controls.exports_clientes]
  bucket     = aws_s3_bucket.exports_clientes.id
  acl        = "public-read" # "para o dashboard conseguir ler"
}
