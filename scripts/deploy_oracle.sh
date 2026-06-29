#!/usr/bin/env bash
set -euo pipefail

# Navigwiz + Acronous AI — Oracle Cloud Free Tier Deployment Script
# Run this ONCE on a fresh Oracle Cloud Ubuntu 22.04/24.04 VM (4 ARM cores, 24 GB RAM, 200 GB disk)
# curl -fsSL https://raw.githubusercontent.com/hritesh023/Navigwiz/main/scripts/deploy_oracle.sh | bash

REPO_URL="https://github.com/hritesh023/Navigwiz.git"
INSTALL_DIR="$HOME/navigwiz"

echo "=== Installing Docker ==="
sudo apt-get update -qq
sudo apt-get install -y -qq ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -qq
sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-v2
sudo usermod -aG docker $USER

echo "=== Cloning Navigwiz ==="
git clone --depth=1 "$REPO_URL" "$INSTALL_DIR"
cd "$INSTALL_DIR/backend"

echo ""
echo "============================================="
echo "  IMPORTANT: Configure your .env file now"
echo "============================================="
echo ""
echo "Copying .env.example to .env — you MUST edit it:"
cp ../.env.example .env
echo ""
echo "Required keys to add (nano .env or vi .env):"
echo "  OPENAI_API_KEY=sk-..."
echo "  SUPABASE_URL=https://mqhioluzqomshbzitkkp.supabase.co"
echo "  SUPABASE_ANON_KEY=eyJ... (from your Flutter project)"
echo "  SUPABASE_SERVICE_KEY=... (from Supabase dashboard)"
echo "  JWT_SECRET=<a-random-64-char-string>"
echo "  SEARXNG_URL=https://searx.be/search"
echo ""
echo "EDIT THE .env FILE NOW, then run:"
echo "  docker compose -f docker-compose.oracle.yml up -d"
echo ""
echo "After that, your brain runs 24/7 on Oracle Cloud."
echo ""

exec "$SHELL"
