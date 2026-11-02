# infra-dados - bucket de exports de clientes, "seguro por padrão" (também é o GABARITO do exercício Axion).
# O dashboard lê via IAM role (menor privilégio), nunca via acesso público.

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

resource "aws_kms_key" "dados_clientes" {
  #checkov:skip=CKV2_AWS_64:Key policy padrão da conta nesta demo; em produção, policy explícita via módulo da plataforma
  description         = "Chave dos exports de clientes (LGPD)"
  enable_key_rotation = true

  tags = {
    owner               = "squad-dados"
    cost_center         = "CC-3001-DADOS"
    data_classification = "confidencial"
  }
}

resource "aws_s3_bucket" "exports_clientes" {
  # Exceções ACEITAS e documentadas (decisão de risco aprovada no PR #42 - ver ADR-007):
  #checkov:skip=CKV_AWS_144:Replicação cross-region dobra o custo; RPO de 24h atendido por backup diário
  #checkov:skip=CKV2_AWS_62:Não há consumidor de eventos para este bucket
  #checkov:skip=CKV_AWS_18:Acesso auditado via CloudTrail data events na conta de segurança
  bucket = "axion-exports-clientes"

  tags = {
    owner               = "squad-dados"
    cost_center         = "CC-3001-DADOS"
    data_classification = "confidencial" # LGPD: contém dados pessoais
  }
}

resource "aws_s3_bucket_public_access_block" "exports_clientes" {
  bucket                  = aws_s3_bucket.exports_clientes.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "exports_clientes" {
  bucket = aws_s3_bucket.exports_clientes.id
  rule {
    object_ownership = "BucketOwnerEnforced" # desliga ACLs de vez
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "exports_clientes" {
  bucket = aws_s3_bucket.exports_clientes.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.dados_clientes.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "exports_clientes" {
  bucket = aws_s3_bucket.exports_clientes.id
  versioning_configuration {
    status = "Enabled" # protege contra exclusão acidental / ransomware
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "exports_clientes" {
  bucket = aws_s3_bucket.exports_clientes.id
  rule {
    id     = "expira-exports-antigos"
    status = "Enabled"
    filter {}
    expiration {
      days = 90 # LGPD: minimização - não guardar dado pessoal além do necessário
    }
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
