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
echo "=================================================="
echo "  CI/CD Stack — Initial Configuration"
echo "=================================================="
echo ""

wait_for "Gitea"     "http://localhost:3000"       30
wait_for "Nexus"     "http://localhost:8081"       60
wait_for "Jenkins"   "http://localhost:8080/login" 150
wait_for "SonarQube" "http://localhost:9000"       60

# -- Nexus -------------------------------------------------------------------------
echo ""
info "Configure NEXUS → http://localhost:8081"
info "Nexus username: admin"
NEXUS_PASS=$(docker exec nexus cat /nexus-data/admin.password 2>/dev/null || echo "already set — use the password you chose during setup")
echo -e "  ${CYAN}Temporary Nexus admin password: ${NEXUS_PASS}${NC}"
echo "   1. Log in with the password above"
echo "   2. Complete the setup wizard and set a new password — save it (you need to login again)"
echo "   3. Verify 'maven-releases' exists under Browse"
echo ""

# -- Gitea -------------------------------------------------------------------------
echo ""
info "Configure GITEA → http://localhost:3000"
echo "   1. Complete the install page at http://localhost:3000/install"
echo "      Database type: PostgreSQL"
echo "      Host: gitea-db:5432"
echo "      Username: gitea"
echo "      Password: gitea_pass"
echo "      Database name: gitea"
echo "      Create an admin account — save the username and password"
echo "   2. Go to Settings → Applications → Generate Token:"
echo "      Name: jenkins"
echo "      Permissions: repository read/write, organization read, user read"
echo "      Save the token — it is only shown once"
echo "   3. Create a private organization named: devops-org"
echo "   4. Inside devops-org, create a repository named: my-app"
echo "      Initialize with main branch"
echo ""
read -p "   Enter your Gitea token to configure the webhook automatically: " GITEA_TOKEN

GITEA_ORG="devops-org"
GITEA_REPO="my-app"
JENKINS_URL="http://jenkins:8080"

curl -sf -X POST "http://localhost:3000/api/v1/repos/${GITEA_ORG}/${GITEA_REPO}/hooks" \
  -H "Authorization: token ${GITEA_TOKEN}" \
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
echo ""
# -- SonarQube ---------------------------------------------------------------------
echo ""
info "Configure SONARQUBE → http://localhost:9000 (admin / admin)"
echo "   1. Log in and change the default password"
echo "   2. Go to http://localhost:9000/admin/webhooks → Create:"
echo "      Name: jenkins"
echo "      URL: http://jenkins:8080/sonarqube-webhook/"
echo "      Secret: leave blank"
echo "   3. Go to http://localhost:9000/account/security → Generate Token:"
echo "      Name: jenkins"
echo "      Type: Global Analysis Token"
echo "      Expiration: No expiration"
echo "      Save the token — it is only shown once"
echo ""

# -- Jenkins -----------------------------------------------------------------------
echo ""
info "Configure JENKINS → http://localhost:8080"
JENKINS_PASS=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "already set — use the password you chose during setup")
echo -e "  ${CYAN}Jenkins unlock key: ${JENKINS_PASS}${NC}"
echo ""
echo "   1. Paste the unlock key above"
echo "   2. Install suggested plugins"
echo "   3. Create an admin user and change the Jenkins URL to https://jenkins:8080/ — save the username and password"
echo ""
echo "   4. Install extra plugins:"
echo "      Manage Jenkins → Plugins → Available:"
echo "      - Gitea"
echo "      - SonarQube Scanner"
echo "      - Nexus Artifact Uploader"
echo "      - Docker Pipeline"
echo "      - Eclipse Temurin installer"
echo "      Restart Jenkins after installing"
echo ""
echo "   5. Add credentials:"
echo "      Manage Jenkins → Credentials → System → Global → Add credentials:"
echo ""
echo "      nexus-creds:"
echo "        Kind: Username with password"
echo "        Username: admin"
echo "        Password: (your Nexus password)"
echo "        ID: nexus-creds"
echo ""
echo "      gitea-token:"
echo "        Kind: Gitea Personal Access Token"
echo "        Token: (token from Gitea)"
echo "        ID: gitea-token"
echo ""
echo "      sonarqube-token:"
echo "        Kind: Secret text"
echo "        Secret: (token from SonarQube)"
echo "        ID: sonarqube-token"
echo ""
echo "   6. Configure SonarQube server:"
echo "      Manage Jenkins → System → SonarQube servers → Add:"
echo "      Name: SonarQube"
echo "      Server URL: http://sonarqube:9000"
echo "      Server authentication token: sonarqube-token"
echo ""
echo "   7. Add Gitea server:"
echo "      Manage Jenkins ?~F~R System ?~F~R Gitea Servers ?~F~R Add:"
echo "      Name: gitea"
echo "      URL: http://gitea:3000"
echo "      Credentials: gitea-token"
echo ""
echo "   8. Configure tools:"
echo "      Manage Jenkins → Tools:"
echo ""
echo "      JDK:"
echo "        Name: JDK-21"
echo "        Install automatically: Adoptium → any Java 21 version"
echo ""
echo "      Maven:"
echo "        Name: Maven-3.9"
echo "        Install automatically → 3.9.x"
echo ""
echo "   9. Create Multibranch Pipeline:"
echo "       New Item → my-app → Multibranch Pipeline → OK"
echo "       Branch Sources → Add source → Gitea:"
echo "         Server: gitea"
echo "         Credentials: gitea-token"
echo "         Owner: devops-org"
echo "         Repository: my-app"
echo "       Save → Jenkins scans automatically"
echo ""

# -- Push your project -------------------------------------------------------------
echo ""
info "Push your Java project (with Jenkinsfile + Dockerfile at root):"
echo "   1. Copy Jenkinsfile and Dockerfile into your project root"
echo "   2. Edit Jenkinsfile:"
echo "        APP_NAME  = 'my-app'          // your Maven artifactId"
echo "        NEXUS_REPO = 'maven-releases'"
echo "        jdk 'JDK-21'"
echo "   3. Push:"
echo "        cd your-project"
echo "        git init"
echo "        git add ."
echo "        git commit -m 'initial commit'"
echo "        git remote add origin http://localhost:3000/devops-org/my-app.git"
echo "        git push -u origin main"
echo "   → Pipeline triggers automatically via webhook"
echo ""
echo "=================================================="
echo -e "${GREEN}  Done! Follow the steps above in order.${NC}"
echo "=================================================="
echo ""
