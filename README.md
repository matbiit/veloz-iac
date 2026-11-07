# Aula 2 — Da console ao pull request (VeloZ: IaC + GitOps)

**MBA em Arquitetura e Engenharia de Software · Engenharia de Software Moderna**

A VeloZ precisa subir um **ambiente de teste de carga para a Black Friday (27/11/2026)**,
garantir que nenhum bucket de dados de clientes vá parar na internet e acabar com o
*drift* manual nos servidores. Tudo como código, revisado em pull request.
**Sem Docker:** containers com **Podman** (sem daemon, rootless).

## Mapa de código por tema da aula

| Tema | Arquivo para projetar | Comando para rodar ao vivo |
|---|---|---|
| **Podman** (runtime sem daemon) | `vitrine/Containerfile` | `podman build --format docker -t localhost/veloz-vitrine:1.4.0 vitrine/` |
| **Terraform — módulo da plataforma** | `terraform/modules/servico-web/` | `terraform plan -var-file=envs/dev.tfvars` |
| **Terraform — ambientes e estado** | `terraform/envs/*.tfvars`, `terraform/backend.tf` | `terraform workspace new blackfriday` |
| **Ansible — deploy com Podman** | `ansible/deploy_vitrine.yml` | `ansible-playbook deploy_vitrine.yml` |
| **Ansible — hardening e auditoria** | `ansible/hardening.yml` | `ansible-playbook hardening.yml --check --diff` |
| **Políticas como código (nuvem)** | `policies/s3.rego` + testes | `conftest test --parser hcl2 -p policies exercicio-axion/main.tf` |
| **Políticas como código (deploy)** | `policies/kube.rego` + testes | `conftest test -p policies --namespace kubernetes gitops/apps/*.yaml` |
| **GitOps pull (agente)** | `gitops/reconciliador.py` + `gitops/apps/vitrine.yaml` | `python gitops/reconciliador.py --repo . --intervalo 10` |
| **GitOps em produção** | `gitops/argocd-vitrine.yaml` | (ArgoCD num cluster) |
| **Pipeline e governança** | `.github/workflows/iac.yml`, `.github/CODEOWNERS` | `bash scripts/verificar.sh` |
| **Decisão executiva** | `docs/ADR-002-politica-de-mudancas-em-producao.md` | — |

| Outras pastas | O que tem |
|---|---|
| `infra-dados/` | bucket S3 de exports de clientes "seguro por padrão" (gabarito do desafio) |
| `exercicio-axion/` | o mesmo bucket gerado por IA, inseguro (desafio individual; fora do pipeline) |
| branch `demo/bucket-gerado-por-ia` | PR "urgente" com bucket público → pipeline vermelho |

> **Terraform ou OpenTofu?** Os comandos são idênticos (`terraform` ↔ `tofu`). Tudo aqui foi testado com OpenTofu 1.10 e Podman 4.9.
>
> **Por que o provider se chama `docker`?** O Podman expõe uma API compatível com a do Docker. O provider `kreuzwerker/docker`
> só conversa por HTTP com o socket do Podman; nenhum Docker é instalado. Três ajustes no módulo tornam isso estável:
> `ports.ip = ""`, `pid_mode = "private"` e `lifecycle.ignore_changes` no IPAM da rede (comentados no código).

---

## Tutorial 0 — Ambiente (faça ANTES da aula)

**GitHub Codespaces ou Linux (Ubuntu/Debian):**
```bash
sudo apt-get update && sudo apt-get install -y podman
# Terraform (ou OpenTofu: https://opentofu.org/docs/intro/install/)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y terraform
pip install ansible checkov pyyaml          # o pacote "ansible" já traz a coleção containers.podman
curl -sSL https://github.com/open-policy-agent/conftest/releases/download/v0.62.0/conftest_0.62.0_Linux_x86_64.tar.gz | tar xz conftest && sudo mv conftest /usr/local/bin/
podman pull docker.io/library/nginx:1.27-alpine docker.io/library/redis:7.4-alpine
bash scripts/podman-api.sh                  # API do Podman para o Terraform (use --root se o rootless falhar)
```
**macOS/Windows:** Podman Desktop + `podman machine init && podman machine start`; o socket aparece em `podman machine inspect`.
Se o seu ambiente rootless não tiver delegação de cgroup (erro de limite de memória), use `-var limitar_memoria=false`.

---

## Tutorial 1 — Podman em 5 comandos

```bash
podman run -d --name teste -p 8085:80 docker.io/library/nginx:1.27-alpine   # sem daemon, sem root
podman ps                                                                    # processo do seu usuário
podman generate kube teste > /tmp/teste.yaml                                 # vira YAML de Kubernetes
podman rm -f teste && podman kube play /tmp/teste.yaml                       # e volta a rodar a partir do YAML
podman kube down /tmp/teste.yaml
```

## Tutorial 2 — Terraform: init → plan → apply → destroy

```bash
cd terraform
terraform init
terraform workspace new dev
terraform plan -var-file=envs/dev.tfvars -out=dev.plan     # Plan: 5 to add (rede, 2 imagens, vitrine-0, cache-0)
terraform apply dev.plan
curl localhost:8080
podman ps --format '{{.Names}}  {{.Labels}}'               # labels de owner/cost_center em tudo
terraform plan -var-file=envs/dev.tfvars                   # No changes: idempotência
```
**Drift (caso Pulsar):** `podman rm -f dev-vitrine-0` → `terraform plan` mostra `1 to add` → `terraform apply` corrige.
**Guarda-corpo:** `terraform plan -var-file=envs/dev.tfvars -var imagem_vitrine=docker.io/library/nginx:latest` → `Invalid value for variable`.
**Ambiente efêmero:** `terraform workspace new blackfriday && terraform apply -var-file=envs/blackfriday.tfvars` (8 recursos, portas 9080–9083) → `terraform destroy ...`.
Estado remoto com lock (caso Axion): `terraform/backend.tf`.

## Tutorial 3 — Ansible com Podman

```bash
cd ansible
ansible-playbook deploy_vitrine.yml                     # build da imagem + 2 réplicas (portas 8180, 8181): changed=3
ansible-playbook deploy_vitrine.yml                     # changed=0 (idempotente)
podman stop hml-vitrine-ansible-1                       # alguém "mexeu"
ansible-playbook deploy_vitrine.yml --check --diff      # auditoria: aponta a réplica parada, sem alterar nada
ansible-playbook deploy_vitrine.yml                     # corrige: changed=1
ansible-playbook deploy_vitrine.yml -e versao=1.5.0     # nova versão, uma réplica por vez
ansible-playbook deploy_vitrine.yml -e estado=absent    # remove tudo
sudo ansible-playbook hardening.yml --check --diff      # caso GHS: baseline de segurança (use --skip-tags pacotes sem internet)
```

## Tutorial 4 — Políticas como código

```bash
conftest verify -p policies                                                    # as próprias regras têm teste (9)
checkov -d exercicio-axion --framework terraform --compact                     # 13 falhas de mercado
conftest test --parser hcl2 -p policies exercicio-axion/main.tf                # 7 falhas das regras da empresa
conftest test -p policies --namespace kubernetes gitops/apps/vitrine.yaml      # manifesto de deploy: aprovado
```
**Desafio individual (13 min):** corrigir `exercicio-axion/main.tf` até o `conftest` passar e o `checkov` ficar só com
exceções justificadas (`#checkov:skip=ID:motivo`). Gabarito: `infra-dados/main.tf`.
Sem ambiente? Trilha de revisão: leia `infra-dados/main.tf` e responda no formulário que regra cada recurso novo atende.

## Tutorial 5 — GitOps pull com o agente da aula

```bash
python gitops/reconciliador.py --repo . --intervalo 10        # em outro terminal; observa a branch main
curl localhost:8090                                           # VeloZ vitrine - prod - 1.4.0
```
| Faça | O agente mostra |
|---|---|
| `podman pod stop vitrine-pod` | `SELFHEAL` e recria o pod |
| altere `VERSAO` para `"1.5.0"` em `gitops/apps/vitrine.yaml` e faça commit | `SYNC` e `curl` mostra 1.5.0 |
| troque a imagem para `...nginx:latest` e faça commit | `BLOQUEADO ... [K8S-001]`; a versão anterior continua no ar |
| `git revert HEAD` | volta ao estado aprovado |
| `git rm gitops/apps/vitrine.yaml` e commit | `PRUNE`: o que saiu do Git sai do ambiente |

Em produção, o mesmo papel é do ArgoCD ou do Flux dentro do cluster (`gitops/argocd-vitrine.yaml`).

## Tutorial 6 — Pipeline e governança no GitHub

1. `gh repo create veloz-iac --private --source . --push` e `git push origin demo/bucket-gerado-por-ia`.
2. **Settings → Branches (main):** exigir PR, o check "Portões de qualidade e segurança" e revisão de Code Owners.
3. `gh pr create --head demo/bucket-gerado-por-ia --title "bucket relatórios parceiros BF" --body "urgente"` → checkov e conftest bloqueiam.
4. Portões localmente: `bash scripts/verificar.sh`.
