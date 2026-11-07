#!/usr/bin/env bash
# Roda localmente os mesmos portões do pipeline (útil para ensaiar antes da aula).
# Requer: tofu (ou terraform), checkov, conftest.  Uso: bash scripts/verificar.sh
set -uo pipefail
TF=$(command -v tofu || command -v terraform)
ok=0

passo () { echo; echo "▶ $1"; }

passo "1) fmt";        $TF fmt -check -recursive || ok=1
passo "2) validate";   for d in terraform infra-dados; do (cd "$d" && $TF init -backend=false -input=false >/dev/null && $TF validate) || ok=1; done
passo "3) checkov";    checkov -d . --framework terraform --skip-path exercicio-axion --compact --quiet || ok=1
passo "4) políticas";  conftest verify -p policies && conftest test --parser hcl2 -p policies infra-dados/*.tf || ok=1
passo "5) manifestos"; conftest test -p policies --namespace kubernetes gitops/apps/*.yaml || ok=1
passo "6) ansible";    ansible-playbook --syntax-check -i ansible/inventario.ini ansible/*.yml >/dev/null || ok=1

echo
[ $ok -eq 0 ] && echo "✅ Todos os portões passaram" || echo "❌ Algum portão falhou - o PR seria bloqueado"
exit $ok
