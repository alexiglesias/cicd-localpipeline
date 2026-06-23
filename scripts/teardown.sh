#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# scripts/teardown.sh — stop + clean the CI/CD stack
# Use --volumes to also delete all data (full reset)
# ─────────────────────────────────────────────────────────────────────────────

YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'

if [[ "$1" == "--volumes" ]]; then
    echo -e "${YELLOW}WARNING: This will delete ALL data (Gitea repos, Jenkins jobs, Nexus artifacts).${NC}"
    read -p "Are you sure? (yes/no): " confirm
    [[ "$confirm" != "yes" ]] && echo "Aborted." && exit 0
    docker compose down --volumes --remove-orphans
    echo -e "${GREEN}Stack stopped and all volumes deleted.${NC}"
else
    docker compose down --remove-orphans
    echo -e "${GREEN}Stack stopped. Data volumes preserved.${NC}"
    echo "Tip: run with --volumes to do a full reset."
fi
