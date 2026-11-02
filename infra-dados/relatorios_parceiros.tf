# Gerado por assistente de IA. Prompt do dev (sexta, 17h40):
# "preciso de um bucket para os parceiros baixarem o relatório de vendas da Black Friday, rápido"
resource "aws_s3_bucket" "relatorios_parceiros" {
  bucket = "axion-relatorios-parceiros-bf"
}

resource "aws_s3_bucket_acl" "relatorios_parceiros" {
  bucket = aws_s3_bucket.relatorios_parceiros.id
  acl    = "public-read"
}
