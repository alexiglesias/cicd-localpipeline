#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# scripts/initial-config.sh — run ONCE after `./setup.sh`
# Bootstraps: Gitea user + org + repo | Nexus maven-releases repo | Jenkins pw
# ─────────────────────────────────────────────────────────────────────────────

set -e
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✔ $1${NC}"; }
info() { echo -e "${CYAN}ℹ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }

# ── Wait for services to be healthy ──────────────────────────────────────────
wait_for() {
    local name=$1 url=$2 retries=30
    printf "Waiting for %-12s" "$name…"
    until curl -sf "$url" &>/dev/null; do
        sleep 3; ((retries--))
        [[ $retries -eq 0 ]] && echo "" && warn "$name did not respond in time" && return 1
        printf "."
    done
    echo ""
    ok "$name is up"
}

echo ""
echo "══════════════════════════════════════════════════"
echo "  CI/CD Stack — Initial Configuration"
echo "══════════════════════════════════════════════════"
echo ""

wait_for "Gitea"     "http://localhost:3000"
wait_for "Nexus"     "http://localhost:8081"
wait_for "Jenkins"   "http://localhost:8080"
wait_for "SonarQube" "http://localhost:9000"

# ── Gitea: create admin + org + repo ─────────────────────────────────────────
echo ""
info "Configuring Gitea…"

GITEA_ADMIN="devops-admin"
GITEA_PASS="Admin1234!"        # change this after first login
GITEA_ORG="devops-org"
GITEA_REPO="my-app"            # match your APP_NAME in Jenkinsfile

# Create admin user (only works if Gitea first-run is done via install page first)
# Open http://localhost:3000/install and submit the form with these values, then run this script.
info "Ensure you completed the Gitea install page at http://localhost:3000/install"
info "Admin user: ${GITEA_ADMIN} | Password: ${GITEA_PASS}"

# Create org
curl -sf -X POST "http://localhost:3000/api/v1/orgs" \
  -u "${GITEA_ADMIN}:${GITEA_PASS}" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${GITEA_ORG}\",\"visibility\":\"private\"}" && ok "Org '${GITEA_ORG}' created" || warn "Org may already exist"

# Create repo under org
curl -sf -X POST "http://localhost:3000/api/v1/orgs/${GITEA_ORG}/repos" \
  -u "${GITEA_ADMIN}:${GITEA_PASS}" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"${GITEA_REPO}\",\"private\":true,\"auto_init\":true,\"default_branch\":\"main\"}" \
  && ok "Repo '${GITEA_ORG}/${GITEA_REPO}' created" || warn "Repo may already exist"

# Create webhook pointing to Jenkins
JENKINS_URL="http://jenkins:8080"
curl -sf -X POST "http://localhost:3000/api/v1/repos/${GITEA_ORG}/${GITEA_REPO}/hooks" \
  -u "${GITEA_ADMIN}:${GITEA_PASS}" \
  -H "Content-Type: application/json" \
  -d "{
    \"type\":\"gitea\",
    \"active\":true,
    \"events\":[\"push\",\"pull_request\"],
    \"config\":{
      \"url\":\"${JENKINS_URL}/gitea-webhook/post\",
      \"content_type\":\"json\",
      \"secret\":\"webhook-secret-change-me\"
    }
  }" && ok "Webhook → Jenkins configured" || warn "Webhook may already exist"

# ── Nexus: retrieve initial admin password ────────────────────────────────────
echo ""
info "Nexus initial admin password:"
NEXUS_PASS=$(docker exec nexus cat /nexus-data/admin.password 2>/dev/null || echo "NOT FOUND YET")
echo ""
echo -e "  ${CYAN}Nexus admin password: ${NEXUS_PASS}${NC}"
echo "  → Go to http://localhost:8081 and change it"
echo "  → Create a 'maven-releases' hosted repo (if not already there)"
echo ""

# ── Jenkins: initial unlock key ───────────────────────────────────────────────
info "Jenkins initial admin password:"
JENKINS_PASS=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "NOT FOUND YET")
echo ""
echo -e "  ${CYAN}Jenkins unlock key: ${JENKINS_PASS}${NC}"
echo "  → Go to http://localhost:8080 and paste this key"
echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
echo "══════════════════════════════════════════════════"
echo -e "${GREEN}  Done! Manual steps remaining:${NC}"
echo "══════════════════════════════════════════════════"
echo ""
echo "  1. GITEA  → http://localhost:3000"
echo "       • Complete install at /install if not done"
echo "       • Remote: git remote add origin http://localhost:3000/${GITEA_ORG}/${GITEA_REPO}.git"
echo ""
echo "  2. JENKINS → http://localhost:8080"
echo "       • Install suggested plugins + these extras:"
echo "         Gitea / SonarQube Scanner / Nexus Artifact Uploader / Docker Pipeline"
echo "       • Manage Jenkins → Credentials → Add:"
echo "           ID: nexus-creds     (Nexus admin user/pass)"
echo "           ID: gitea-token     (Gitea personal access token)"
echo "       • Manage Jenkins → System → SonarQube servers → Add (http://sonarqube:9000)"
echo "       • Manage Jenkins → Tools → JDK (JDK-17) + Maven (Maven-3.9)"
echo "       • New Item → Multibranch Pipeline → Gitea source → your repo"
echo ""
echo "  3. SONARQUBE → http://localhost:9000 (admin / admin)"
echo "       • Change default password"
echo "       • Administration → Webhooks → Add: http://jenkins:8080/sonarqube-webhook/"
echo ""
echo "  4. NEXUS → http://localhost:8081"
echo "       • Finish setup wizard, create 'maven-releases' hosted repo"
echo ""
echo "  5. Push your Java project (with Jenkinsfile + Dockerfile at root):"
echo "       cd your-project"
echo "       git remote add origin http://localhost:3000/${GITEA_ORG}/${GITEA_REPO}.git"
echo "       git push -u origin main"
echo ""
