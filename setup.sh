#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# setup.sh — macOS prerequisite check + first-launch helper
# Run: chmod +x setup.sh && ./setup.sh
# ─────────────────────────────────────────────────────────────────────────────

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✔ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
fail() { echo -e "${RED}✘ $1${NC}"; exit 1; }

echo ""
echo "══════════════════════════════════════════════════"
echo "  CI/CD Stack — macOS Setup Check"
echo "══════════════════════════════════════════════════"
echo ""

# ── 1. Docker Desktop ────────────────────────────────────────────────────────
if docker info &>/dev/null; then
    ok "Docker Desktop is running"
else
    fail "Docker Desktop is not running. Start it from Applications and retry."
fi

# ── 2. docker compose (v2) ───────────────────────────────────────────────────
if docker compose version &>/dev/null; then
    ok "docker compose v2 available"
else
    fail "docker compose v2 not found. Update Docker Desktop to a recent version."
fi

# ── 3. Enough RAM for the stack ──────────────────────────────────────────────
# Docker Desktop on macOS defaults to 2GB — the stack needs at least 6GB
DOCKER_MEM=$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0)
DOCKER_MEM_GB=$(echo "scale=1; $DOCKER_MEM / 1073741824" | bc)
if (( $(echo "$DOCKER_MEM_GB >= 5.5" | bc -l) )); then
    ok "Docker memory: ${DOCKER_MEM_GB}GB (sufficient)"
else
    warn "Docker memory: ${DOCKER_MEM_GB}GB — the stack needs at least 6GB."
    warn "Go to Docker Desktop → Settings → Resources → Memory → set to 6GB+"
fi

# ── 4. vm.max_map_count (needed by SonarQube) ────────────────────────────────
# On macOS this lives inside the Docker VM, not the host — handled automatically
ok "SonarQube kernel settings: handled by Docker Desktop VM on macOS"

# ── 5. Free ports ────────────────────────────────────────────────────────────
PORTS=(3000 2222 8080 8081 9000 50000 8090)
for port in "${PORTS[@]}"; do
    if lsof -i ":$port" &>/dev/null; then
        warn "Port $port is already in use — may conflict with the stack"
    else
        ok "Port $port is free"
    fi
done

echo ""
echo "══════════════════════════════════════════════════"
echo "  Starting the CI/CD stack…"
echo "══════════════════════════════════════════════════"
echo ""

# Pull images first so startup is cleaner
docker compose pull

# Start everything
docker compose up -d

echo ""
echo -e "${GREEN}Stack is up! Services:${NC}"
echo ""
echo "  Gitea      → http://localhost:3000   (Git server)"
echo "  Jenkins    → http://localhost:8080   (CI/CD)"
echo "  Nexus      → http://localhost:8081   (Artifacts)"
echo "  SonarQube  → http://localhost:9000   (Code quality)"
echo ""
echo "Next steps:"
echo "  1. Wait ~2 min for all services to finish initialising"
echo "  2. Run: ./scripts/initial-config.sh"
echo "     (sets up Gitea org, Nexus repo, Jenkins credentials)"
echo ""
