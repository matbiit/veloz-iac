# Políticas como código (OPA/Rego) - regras corporativas para buckets S3.
# Rodam no pull request ANTES do apply:  conftest test --parser hcl2 -p policies <pasta>/*.tf
# Diferença para o checkov: checkov traz centenas de regras genéricas de mercado;
# aqui escrevemos as regras ESPECÍFICAS da empresa (tags de FinOps, classificação LGPD...).

package main

import rego.v1

tags_obrigatorias := {"owner", "cost_center", "data_classification"}

acls_publicas := {"public-read", "public-read-write", "authenticated-read"}

buckets := object.get(input, ["resource", "aws_s3_bucket"], {})

# 1) Nenhuma ACL pública, nunca.
deny contains msg if {
	some nome, blocos in object.get(input, ["resource", "aws_s3_bucket_acl"], {})
	some bloco in blocos
	bloco.acl in acls_publicas
	msg := sprintf("[SEG-001] aws_s3_bucket_acl.%s usa ACL '%s'. Dados expostos na internet. Use IAM.", [nome, bloco.acl])
}

# 2) O bloqueio de acesso público tem que estar 100% ligado.
deny contains msg if {
	some nome, blocos in object.get(input, ["resource", "aws_s3_bucket_public_access_block"], {})
	some bloco in blocos
	some campo in ["block_public_acls", "block_public_policy", "ignore_public_acls", "restrict_public_buckets"]
	object.get(bloco, campo, false) != true
	msg := sprintf("[SEG-002] aws_s3_bucket_public_access_block.%s: '%s' deve ser true.", [nome, campo])
}

# 3) Todo bucket precisa das tags corporativas (FinOps + LGPD).
deny contains msg if {
	some nome, blocos in buckets
	some bloco in blocos
	faltando := tags_obrigatorias - {k | some k, _ in object.get(bloco, "tags", {})}
	count(faltando) > 0
	msg := sprintf("[GOV-001] aws_s3_bucket.%s sem tags obrigatórias: %v", [nome, sort(faltando)])
}

# 4) Bucket com dado confidencial precisa de criptografia declarada no mesmo código.
deny contains msg if {
	count(buckets) > 0
	count(object.get(input, ["resource", "aws_s3_bucket_server_side_encryption_configuration"], {})) == 0
	msg := "[SEG-003] Nenhuma aws_s3_bucket_server_side_encryption_configuration declarada (LGPD art. 46)."
}

# 5) Versionamento: aviso (não bloqueia) - decisão de custo do time.
warn contains msg if {
	count(buckets) > 0
	count(object.get(input, ["resource", "aws_s3_bucket_versioning"], {})) == 0
	msg := "[RES-001] Sem versionamento: exclusão acidental ou ransomware não terão volta."
}
