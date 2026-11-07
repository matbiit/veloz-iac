package kubernetes

import rego.v1

base := {
	"kind": "Deployment",
	"metadata": {"name": "vitrine", "labels": {"veloz.owner": "x", "veloz.cost_center": "y"}},
	"spec": {"template": {"spec": {"containers": [{
		"name": "web",
		"image": "docker.io/library/nginx:1.27-alpine",
		"resources": {"limits": {"memory": "128Mi"}},
	}]}}},
}

test_manifesto_conforme if {
	count(deny) == 0 with input as base
}

test_latest_bloqueia if {
	entrada := json.patch(base, [{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value": "nginx:latest"}])
	some msg in deny with input as entrada
	startswith(msg, "[K8S-001]")
}

test_sem_tag_bloqueia if {
	entrada := json.patch(base, [{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value": "docker.io/library/nginx"}])
	some msg in deny with input as entrada
	startswith(msg, "[K8S-001]")
}

test_sem_limite_de_memoria_bloqueia if {
	entrada := json.patch(base, [{"op": "remove", "path": "/spec/template/spec/containers/0/resources"}])
	some msg in deny with input as entrada
	startswith(msg, "[K8S-002]")
}

test_sem_dono_bloqueia if {
	entrada := json.patch(base, [{"op": "remove", "path": "/metadata/labels/veloz.owner"}])
	some msg in deny with input as entrada
	contains(msg, "veloz.owner")
}
