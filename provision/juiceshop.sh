#!/usr/bin/env bash
# provision/juiceshop.sh
#
# Installs OWASP Juice Shop via Docker. Juice Shop is intentionally vulnerable;
# flags here are "derived", so nothing is planted from flags.env.
#
# Reachable at http://192.168.56.22/  (container port 3000 mapped to host 80).
set -uo pipefail
log() { echo "[provision:juiceshop] $*"; }
export DEBIAN_FRONTEND=noninteractive

log "installing Docker..."
apt-get update -y >/dev/null 2>&1
apt-get install -y docker.io >/dev/null 2>&1 || { log "ERROR: docker install failed"; exit 0; }
systemctl enable --now docker >/dev/null 2>&1 || true

log "pulling and running Juice Shop (needs build-time internet, runs offline after)..."
docker pull bkimminich/juice-shop >/dev/null 2>&1 || log "WARNING: image pull failed"

# (re)create the container, mapping :3000 -> :80, auto-restart
docker rm -f juiceshop >/dev/null 2>&1 || true
docker run -d --name juiceshop --restart unless-stopped \
  -p 80:3000 bkimminich/juice-shop >/dev/null 2>&1 || \
  log "WARNING: could not start Juice Shop container"

log "Juice Shop should be at http://192.168.56.22/ (find the hidden Score Board first)."
