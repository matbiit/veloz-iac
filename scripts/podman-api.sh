#!/usr/bin/env bash
# Sobe a API REST do Podman (compatível com a do Docker) para o Terraform conversar com ela.
# Não existe daemon permanente: é um processo comum do seu usuário, que você encerra quando quiser.
#
#   bash scripts/podman-api.sh            # rootless (recomendado): containers do seu usuário
#   bash scripts/podman-api.sh --root     # rootful, para ambientes sem suporte a rootless (ex.: alguns Codespaces)
#   bash scripts/podman-api.sh --parar
#
# Em Linux com systemd, a alternativa "oficial" é:  systemctl --user enable --now podman.socket
# (socket em unix://$XDG_RUNTIME_DIR/podman/podman.sock -> passe em -var container_host=...).
set -euo pipefail

SOCK="${PODMAN_SOCK:-/tmp/podman.sock}"
PID_FILE="/tmp/podman-api.pid"

if [[ "${1:-}" == "--parar" ]]; then
  [[ -f "$PID_FILE" ]] && { sudo -n kill "$(cat "$PID_FILE")" 2>/dev/null || kill "$(cat "$PID_FILE")"; rm -f "$PID_FILE"; }
  echo "API do Podman encerrada."; exit 0
fi

PREFIXO=""
[[ "${1:-}" == "--root" ]] && PREFIXO="sudo"

$PREFIXO podman system service --time=0 "unix://$SOCK" >/tmp/podman-api.log 2>&1 &
echo $! > "$PID_FILE"
for _ in $(seq 1 20); do [[ -S "$SOCK" ]] && break; sleep 0.25; done
[[ -n "$PREFIXO" ]] && sudo chmod 660 "$SOCK" && sudo chgrp "$(id -gn)" "$SOCK"

if curl -fsS --unix-socket "$SOCK" http://podman/v1.41/version >/dev/null; then
  echo "✅ API do Podman em unix://$SOCK"
  echo "   Terraform: já é o default de var.container_host (ou: export TF_VAR_container_host=unix://$SOCK)"
  [[ -n "$PREFIXO" ]] && echo "   Modo root: use 'sudo podman ps' para ver os mesmos containers que o Terraform criar."
else
  echo "❌ A API não respondeu. Veja /tmp/podman-api.log"; exit 1
fi
