# Aula 2 — VeloZ: da console ao pull request (IaC + GitOps)

**MBA em Arquitetura e Engenharia de Software · Engenharia de Software Moderna**

A VeloZ precisa subir um **ambiente de teste de carga para a Black Friday (27/11/2026)**,
garantir que nenhum bucket de dados de clientes vá parar na internet e acabar com o
*drift* manual nos servidores. Tudo como código, revisado em pull request.

| Pasta | O que tem | Caso / conceito |
|---|---|---|
| `terraform/` | loja VeloZ (vitrine + cache) em Docker, com módulo reutilizável e `.tfvars` por ambiente | Pulsar (drift), módulos, plan/apply/destroy, workspaces |
| `infra-dados/` | bucket S3 de exports de clientes “seguro por padrão” | Axion Data (gabarito) |
| `exercicio-axion/` | o mesmo bucket gerado por IA, inseguro (fora do pipeline) | Exercício em grupo |
| `policies/` | regras OPA/Rego da empresa + testes das regras | Políticas como código |
| `ansible/` | baseline de hardening idempotente | GHS (HIPAA/LGPD, drift em 15% dos servidores) |
| `gitops/` | `Application` do ArgoCD com `selfHeal` | VeloZ (deploy manual derrubou produção) |
| `.github/` | pipeline de portões + `CODEOWNERS` | GitOps, governança |

Branch `demo/bucket-gerado-por-ia`: PR “urgente” que um assistente de IA gerou com bucket público → pipeline vermelho.

> **Terraform ou OpenTofu?** Os comandos são idênticos (`terraform` ↔ `tofu`). O OpenTofu é o fork open source
> (Linux Foundation) criado após a mudança de licença da HashiCorp (BSL, 2023); a HashiCorp hoje pertence à IBM.
> Use o que sua empresa adota — o conteúdo da aula vale para os dois.

---

## Tutorial 0 — Ambiente (faça ANTES da aula)

**GitHub Codespaces (recomendado):** o Codespace padrão já tem Docker. No terminal:
```bash
# Terraform (ou OpenTofu: https://opentofu.org/docs/intro/install/)
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y terraform

pip install checkov ansible-core
curl -sSL https://github.com/open-policy-agent/conftest/releases/download/v0.62.0/conftest_0.62.0_Linux_x86_64.tar.gz | tar xz conftest && sudo mv conftest /usr/local/bin/
docker pull nginx:1.27-alpine && docker pull redis:7.4-alpine     # evita esperar download ao vivo
```
**Local:** Docker Desktop + os mesmos binários (Windows: use WSL2).

---

## Tutorial 1 — Terraform: init → plan → apply → destroy (Bloco 1)

```bash
cd terraform
terraform init                                   # baixa o provider docker (kreuzwerker/docker)
terraform workspace new dev                      # um estado por ambiente
terraform plan  -var-file=envs/dev.tfvars -out=dev.plan
terraform apply dev.plan
curl localhost:8080                              # vitrine no ar
docker ps --format '{{.Names}}\t{{.Labels}}'     # labels de owner/cost_center em tudo
```

**Idempotência** — rode de novo, nada muda:
```bash
terraform plan -var-file=envs/dev.tfvars         # "No changes. Your infrastructure matches the configuration."
```

**Drift (caso Pulsar)** — alguém “resolveu na mão”:
```bash
docker rm -f dev-vitrine-0
terraform plan -var-file=envs/dev.tfvars         # "Plan: 1 to add" -> o código denuncia o desvio
terraform apply -var-file=envs/dev.tfvars -auto-approve
```

**Guarda-corpo no módulo** — tag `latest` é recusada antes de criar qualquer coisa:
```bash
terraform plan -var-file=envs/dev.tfvars -var imagem_vitrine=nginx:latest    # Error: Invalid value for variable
```

**Ambiente efêmero de Black Friday** — mesmo código, outro `.tfvars`:
```bash
terraform workspace new blackfriday
terraform apply -var-file=envs/blackfriday.tfvars -auto-approve     # 4 réplicas nas portas 9080-9083
curl localhost:9083
terraform destroy -var-file=envs/blackfriday.tfvars -auto-approve   # custo zero depois do teste
```
Estado remoto com lock para times (caso Axion: tfstate por e-mail): veja `terraform/backend.tf`.

---

## Tutorial 2 — Segurança e políticas como código (Bloco 2, em grupos)

```bash
checkov -d exercicio-axion --framework terraform --compact          # ~13 falhas de mercado
conftest test --parser hcl2 -p policies exercicio-axion/main.tf     # 7 falhas das regras da empresa
conftest verify -p policies                                         # as próprias regras têm teste
```
**Missão do grupo (20 min):** corrigir `exercicio-axion/main.tf` até `conftest` passar e o `checkov`
ficar só com exceções **justificadas** (`#checkov:skip=ID:motivo`). Gabarito: `infra-dados/main.tf`.

---

## Tutorial 3 — Pipeline GitOps no GitHub (Bloco 3)

1. Suba o repositório: `gh repo create veloz-iac --private --source . --push`
2. **Settings → Branches → Add rule (main):** *Require a pull request*, *Require status checks* (`Portões de qualidade e segurança`), *Require review from Code Owners*.
3. Abra o PR da IA:
   ```bash
   git push origin demo/bucket-gerado-por-ia
   gh pr create --head demo/bucket-gerado-por-ia --title "bucket relatórios parceiros BF" --body "urgente"
   ```
4. Na aba **Checks**: checkov e conftest bloqueiam o merge. A mensagem `[SEG-001]` explica o porquê.
5. Para rodar os portões localmente: `bash scripts/verificar.sh`.

---

## Tutorial 4 — Ansible: idempotência e drift em servidores (caso GHS)

```bash
cd ansible
sudo ansible-playbook hardening.yml --check --diff     # AUDITORIA: o que está fora do padrão (nada é alterado)
sudo ansible-playbook hardening.yml                    # aplica: changed=N
sudo ansible-playbook hardening.yml                    # de novo: changed=0  <- idempotência
sudo chmod 777 /opt/ghs                                # simula "ajuste" manual
sudo ansible-playbook hardening.yml --check --diff     # mostra: mode 0777 -> 0750
sudo ansible-playbook hardening.yml                    # corrige: changed=1
```
Sem internet para `apt`? Acrescente `--skip-tags pacotes`.

---

## Tutorial 5 — GitOps pull com ArgoCD (discussão)

`gitops/argocd-vitrine.yaml` mostra o modelo *pull*: `selfHeal: true` desfaz qualquer `kubectl edit`
manual (o erro que derrubou a VeloZ por 2 horas) e o rollback vira `git revert`.
Para testar de verdade: `kind create cluster` + instalação do ArgoCD (https://argo-cd.readthedocs.io/en/stable/getting_started/).
