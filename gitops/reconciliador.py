"""Mini agente GitOps (modelo PULL) - o que o ArgoCD e o Flux fazem, em ~150 linhas.

O agente roda PERTO do ambiente (no host, ou dentro do cluster) e, em loop:
  1. busca o repositório de deploy no Git           -> Git é a fonte única da verdade
  2. valida cada manifesto com as políticas (OPA)   -> o que viola a política não é aplicado
  3. compara o estado desejado com o que está rodando
  4. aplica a diferença com `podman kube play`      -> sync
  5. recria o que alguém mudou ou derrubou na mão   -> selfHeal
  6. remove o que saiu do Git                       -> prune

Ninguém precisa de credencial do ambiente: quem muda produção é o merge no Git.

Uso:
    python gitops/reconciliador.py --repo .  --caminho gitops/apps --intervalo 10
    python gitops/reconciliador.py --repo https://github.com/<org>/veloz-iac.git --uma-vez
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import shutil
import subprocess
import time
from datetime import datetime

import yaml

ESTADO = pathlib.Path(".gitops-estado")          # cópia do que foi aplicado (para comparar e fazer prune)


def log(evento: str, detalhe: str) -> None:
    print(f"{datetime.now():%H:%M:%S}  {evento:<10} {detalhe}", flush=True)


def sh(*cmd: str, checar: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, check=checar)


# ----------------------------------------------------------------------- 1. Git

def buscar(repo: str, ramo: str, destino: pathlib.Path) -> str:
    if not (destino / ".git").exists():
        sh("git", "clone", "--quiet", "--branch", ramo, repo, str(destino))
    else:
        sh("git", "-C", str(destino), "fetch", "--quiet", "origin", ramo)
        sh("git", "-C", str(destino), "reset", "--quiet", "--hard", f"origin/{ramo}")
    return sh("git", "-C", str(destino), "rev-parse", "--short", "HEAD").stdout.strip()


# ----------------------------------------------------------------------- 2. Política

def politica_ok(manifesto: pathlib.Path, politicas: pathlib.Path | None) -> tuple[bool, str]:
    if politicas is None or shutil.which("conftest") is None:
        return True, ""
    r = sh("conftest", "test", "--no-color", "-p", str(politicas), "--namespace", "kubernetes", str(manifesto), checar=False)
    return r.returncode == 0, " | ".join(linha.strip() for linha in r.stdout.splitlines() if "FAIL" in linha)


# ----------------------------------------------------------------------- 3. Estado real

def nome_do_pod(manifesto: pathlib.Path) -> str:
    doc = yaml.safe_load(manifesto.read_text(encoding="utf-8"))
    nome = doc["metadata"]["name"]
    return nome if doc["kind"] == "Pod" else f"{nome}-pod"       # podman: Deployment X vira pod "X-pod"


def saudavel(pod: str) -> bool:
    r = sh("podman", "pod", "inspect", pod, checar=False)
    if r.returncode != 0:
        return False
    info = json.loads(r.stdout)
    info = info[0] if isinstance(info, list) else info
    containers = [c for c in info.get("Containers", []) if not c.get("Name", "").endswith("-infra")]
    return info.get("State") == "Running" and all(c.get("State") == "running" for c in containers)


def digest(arquivo: pathlib.Path) -> str:
    return hashlib.sha256(arquivo.read_bytes()).hexdigest()[:12]


# ----------------------------------------------------------------------- 4-6. Reconciliação

def reconciliar(apps: pathlib.Path, rev: str, politicas: pathlib.Path | None) -> None:
    ESTADO.mkdir(exist_ok=True)
    desejados = {m.name: m for m in sorted(apps.glob("*.yaml"))}

    for nome, manifesto in desejados.items():
        aplicado = ESTADO / nome
        pod = nome_do_pod(manifesto)
        mudou = not aplicado.exists() or digest(aplicado) != digest(manifesto)
        if not mudou and saudavel(pod):
            continue
        ok, motivo = politica_ok(manifesto, politicas)
        if not ok:
            log("BLOQUEADO", f"{nome} @ {rev} viola a política: {motivo}")
            continue
        log("SYNC" if mudou else "SELFHEAL", f"{nome} @ {rev} -> podman kube play --replace ({'mudou no Git' if mudou else 'drift: pod fora do estado desejado'})")
        r = sh("podman", "kube", "play", "--replace", "--annotation", f"gitops.veloz/revisao={rev}", str(manifesto), checar=False)
        if r.returncode != 0:
            log("ERRO", r.stderr.strip().splitlines()[-1] if r.stderr else "falha no kube play")
            continue
        shutil.copy(manifesto, aplicado)

    for aplicado in ESTADO.glob("*.yaml"):                      # prune: saiu do Git, sai do ambiente
        if aplicado.name not in desejados:
            log("PRUNE", f"{aplicado.name} removido do Git -> podman kube down")
            sh("podman", "kube", "down", str(aplicado), checar=False)
            aplicado.unlink()


def main() -> None:
    a = argparse.ArgumentParser()
    a.add_argument("--repo", required=True, help="URL ou caminho do repositório de deploy")
    a.add_argument("--ramo", default="main")
    a.add_argument("--caminho", default="gitops/apps", help="pasta dos manifestos dentro do repositório")
    a.add_argument("--politicas", default="policies", help="pasta de políticas Rego no repositório ('' desliga)")
    a.add_argument("--intervalo", type=int, default=10)
    a.add_argument("--uma-vez", action="store_true")
    o = a.parse_args()

    copia = pathlib.Path(".gitops-repo")
    log("INICIO", f"observando {o.repo} ({o.ramo}) a cada {o.intervalo}s")
    while True:
        try:
            rev = buscar(o.repo, o.ramo, copia)
            politicas = (copia / o.politicas) if o.politicas else None
            reconciliar(copia / o.caminho, rev, politicas)
        except subprocess.CalledProcessError as erro:
            log("ERRO", (erro.stderr or str(erro)).strip())
        if o.uma_vez:
            break
        time.sleep(o.intervalo)


if __name__ == "__main__":
    main()
