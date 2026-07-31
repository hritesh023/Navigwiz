#!/usr/bin/env bash
#
# Navigwiz + Acronous AI — Oracle Cloud Free Tier setup (Ubuntu, ARM64/Ampere)
#
#  1. Ollama          -> unlimited local LLM token generation (no rate limits)
#  2. cloudflared     -> Cloudflare Tunnel "acronous-oracle" (oracle.acronous.com)
#  3. (optional) Backend FastAPI via Docker Compose, bound to localhost only
#
# Run as root:  sudo bash setup_oracle.sh
#
set -euo pipefail

MODEL="${MODEL:-qwen2.5:14b}"
TUNNEL_TOKEN="eyJhIjoiOGNkOThiNjJhNmRmYzQ4ZTUzMTkxYWI2NDFkNTgwZDYiLCJzIjoiTm1NeE5ERmlZek10TTJZeU55MDBNelprTFRoa05EY3ROakl4TnpNNVl6TTRPR0ZoIiwidCI6ImE0MjY3NzY2LWJkMTgtNGFhNC1hNTFiLTU3NmJjZmMzM2NjZiJ9"
DEPLOY_BACKEND="${DEPLOY_BACKEND:-false}"

log()  { echo -e "\n\e[1;32m==> $*\e[0m"; }
fail() { echo -e "\n\e[1;31mERROR: $*\e[0m" >&2; exit 1; }

command -v curl >/dev/null || fail "curl is required"
command -v jq   >/dev/null || fail "jq is required"

# ---------------------------------------------------------------- 1. Ollama
log "Installing Ollama"
curl -fsSL https://ollama.com/install.sh | sh
systemctl enable --now ollama || true

log "Pulling model: $MODEL (this downloads ~9 GB, one time)"
ollama pull "$MODEL"
ollama run "$MODEL" --keepalive 60s >/dev/null 2>&1 || true

# ----------------------------------------------------------- 2. cloudflared
log "Installing cloudflared"
ARCH="$(dpkg --print-architecture)"
if [ "$ARCH" = "arm64" ]; then
  CLOUDFLARED_DEB="cloudflared-linux-arm64.deb"
else
  CLOUDFLARED_DEB="cloudflared-linux-amd64.deb"
fi
curl -fsSL -o "/tmp/$CLOUDFLARED_DEB" "https://github.com/cloudflare/cloudflared/releases/latest/download/$CLOUDFLARED_DEB"
dpkg -i "/tmp/$CLOUDFLARED_DEB" || apt-get -f install -y

log "Writing tunnel config (oracle.acronous.com: /search -> SearXNG :8888, /api/* -> backend :8000, else Ollama :11434)"
mkdir -p /etc/cloudflared
cat > /etc/cloudflared/config.yml <<'EOF'
tunnel: acronous-oracle
credentials-file: /etc/cloudflared/acronous-oracle.json
ingress:
  - hostname: oracle.acronous.com
    path: /search*
    service: http://localhost:8888
  - hostname: oracle.acronous.com
    path: /api/*
    service: http://localhost:8000
  - hostname: oracle.acronous.com
    service: http://localhost:11434
  - service: http_status:404
no-autoupdate: true
EOF

cat > /etc/cloudflared/acronous-oracle.json <<'EOF'
{"AccountTag":"8cd98b62a6dfc48e53191ab641d580d6","TunnelID":"a4267766-bd18-4aa4-a51b-576bcfc33ccf","TunnelSecret":"NmMxNDFiYzMtM2YyNy00MzZkLTThkN2MtNjIxNzM5YzM4OGYh"}
EOF

log "Starting tunnel service"
cat > /etc/systemd/system/cloudflared-oracle.service <<'EOF'
[Unit]
Description=Cloudflare Tunnel (acronous-oracle)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/cloudflared tunnel --no-autoupdate run --token TOKENPLACEHOLDER
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
sed -i "s|TOKENPLACEHOLDER|${TUNNEL_TOKEN}|" /etc/systemd/system/cloudflared-oracle.service
systemctl daemon-reload
systemctl enable --now cloudflared-oracle

# -------------------------------------------------- 3. Backend (optional)
if [ "$DEPLOY_BACKEND" = "true" ]; then
  log "Deploying FastAPI backend via Docker Compose (localhost only)"
  if ! command -v docker >/dev/null; then
    curl -fsSL https://get.docker.com | sh
  fi
  systemctl enable --now docker || true

  REPO_DIR="${REPO_DIR:-/opt/navigwiz}"
  if [ ! -d "$REPO_DIR" ]; then
    mkdir -p /opt
    git clone --depth 1 https://github.com/hritesh023/Navigwiz.git "$REPO_DIR"
  fi

  cd "$REPO_DIR/backend"
  [ -f .env ] || cp .env.oracle.example .env

  # Bind only to localhost so nothing is exposed except through the tunnel
  sed -i 's/"8000:8000"/"127.0.0.1:8000:8000"/; s/"6379:6379"/"127.0.0.1:6379:6379"/' docker-compose.oracle.yml

  docker compose -f docker-compose.oracle.yml up -d --build
  log "Backend building/running on http://localhost:8000"
else
  echo ""
  echo "Backend deploy skipped. To enable later:  DEPLOY_BACKEND=true sudo bash setup_oracle.sh"
fi

# ------------------------------------------------- 4. SearXNG (search)
log "Installing SearXNG via Docker (localhost:8888, dedicated search backend)"
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi
systemctl enable --now docker || true

mkdir -p /opt/searxng
if [ ! -f /opt/searxng/settings.yml ]; then
  cat > /opt/searxng/settings.yml <<'EOF'
use_default_settings: true
server:
  secret_key: "REPLACE_ME"
  limiter: false
  image_proxy: false
  public_instance: false
  http:
    timeout: 10
search:
  formats:
    - html
    - json
  safe_search: 0
  default_lang: en
  autocomplete: ""
ui:
  static_use_hash: true
EOF
fi
sed -i "s/REPLACE_ME/$(openssl rand -hex 32)/" /opt/searxng/settings.yml

docker rm -f searxng 2>/dev/null || true
docker run -d --name searxng --restart unless-stopped \
  -p 127.0.0.1:8888:8080 \
  -e SEARXNG_BASE_URL=https://oracle.acronous.com/ \
  -v /opt/searxng/settings.yml:/etc/searxng/settings.yml:ro \
  searxng/searxng:latest

# ------------------------------------------------------------- verification
log "Verification"
sleep 10
echo "--- tunnel status ---"
systemctl status cloudflared-oracle --no-pager | head -5 || true
echo "--- ollama models ---"
ollama list
echo "--- local LLM check ---"
curl -fsS http://localhost:11434/v1/models | jq -r '.data[].id' || echo "(ollama not ready yet)"
echo "--- SearXNG check ---"
curl -fsS "http://localhost:8888/search?q=test&format=json" | jq '.results | length' || echo "(searxng not ready yet)"
echo ""
echo "DONE. Public endpoints:"
echo "  LLM      https://oracle.acronous.com/v1/chat/completions"
echo "  Search   https://oracle.acronous.com/search?q=test&format=json"
echo "  Backend  https://oracle.acronous.com/api/v1/health  (when DEPLOY_BACKEND=true)"
