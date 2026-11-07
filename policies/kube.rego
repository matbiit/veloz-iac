# Políticas para os manifestos de deploy (GitOps). Rodam no PR e no próprio agente GitOps:
#   conftest test -p policies --namespace kubernetes gitops/apps/*.yaml

package kubernetes

import rego.v1

containers contains c if {
	some c in input.spec.template.spec.containers
}

containers contains c if {
	input.kind == "Pod"
	some c in input.spec.containers
}

# 1) Versão fixa: sem tag ou com "latest" = drift garantido entre ambientes.
deny contains msg if {
	some c in containers
	not regex.match(`:[^:/]+$`, c.image)
	msg := sprintf("[K8S-001] container '%s' sem tag de versão: %s", [c.name, c.image])
}

deny contains msg if {
	some c in containers
	endswith(c.image, ":latest")
	msg := sprintf("[K8S-001] container '%s' usa 'latest': %s", [c.name, c.image])
}

# 2) Limite de memória obrigatório (um container sem limite derruba os vizinhos).
deny contains msg if {
	some c in containers
	not c.resources.limits.memory
	msg := sprintf("[K8S-002] container '%s' sem resources.limits.memory", [c.name])
}

# 3) Nada de container privilegiado em produção.
deny contains msg if {
	some c in containers
	c.securityContext.privileged == true
	msg := sprintf("[K8S-003] container '%s' privilegiado", [c.name])
}

# 4) FinOps: todo workload tem dono e centro de custo.
deny contains msg if {
	some label in ["veloz.owner", "veloz.cost_center"]
	not input.metadata.labels[label]
	msg := sprintf("[GOV-002] %s '%s' sem label %s", [input.kind, input.metadata.name, label])
}
