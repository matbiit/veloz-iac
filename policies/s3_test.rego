# Política também é código: tem teste unitário.  Rode: conftest verify -p policies

package main

import rego.v1

bucket_ok := {"resource": {
	"aws_s3_bucket": {"b": [{"tags": {"owner": "x", "cost_center": "y", "data_classification": "z"}}]},
	"aws_s3_bucket_server_side_encryption_configuration": {"b": [{}]},
	"aws_s3_bucket_versioning": {"b": [{}]},
}}

test_bucket_conforme_passa if {
	count(deny) == 0 with input as bucket_ok
	count(warn) == 0 with input as bucket_ok
}

test_acl_publica_bloqueia if {
	some msg in deny with input as {"resource": {"aws_s3_bucket_acl": {"a": [{"acl": "public-read"}]}}}
	startswith(msg, "[SEG-001]")
}

test_tag_faltando_bloqueia if {
	entrada := {"resource": {
		"aws_s3_bucket": {"b": [{"tags": {"owner": "x"}}]},
		"aws_s3_bucket_server_side_encryption_configuration": {"b": [{}]},
	}}
	some msg in deny with input as entrada
	contains(msg, "cost_center")
}

test_sem_criptografia_bloqueia if {
	some msg in deny with input as {"resource": {"aws_s3_bucket": {"b": [{"tags": {}}]}}}
	startswith(msg, "[SEG-003]")
}
