# CI/CD Pipeline — Jenkins + Gitea + SonarQube + Nexus

> **Portfolio project:** A fully local, zero-cost CI/CD pipeline that mirrors what you'd find in a real engineering team — without touching a credit card.

---

## Architecture

```
Developer push
     │
     ▼
┌─────────┐   webhook   ┌─────────┐
│  Gitea  │────────────▶│ Jenkins │
│ :3000   │             │ :8080   │
└─────────┘             └────┬────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
        ┌──────────┐  ┌──────────┐  ┌──────────┐
        │SonarQube │  │  Nexus   │  │  Docker  │
        │  :9000   │  │  :8081   │  │ (local)  │
        └──────────┘  └──────────┘  └──────────┘
        Code quality   Artifacts     Running app
```

## Pipeline Stages

| # | Stage | What it does |
|---|-------|-------------|
| 1 | **Checkout** | Pulls source from Gitea |
| 2 | **Build** | `mvn clean package` — compiles and packages the .jar |
| 3 | **Test** | `mvn test` — runs JUnit tests, publishes results |
| 4 | **SonarQube Analysis** | Static analysis + coverage check |
| 5 | **Quality Gate** | Blocks pipeline if code quality thresholds fail |
| 6 | **Publish to Nexus** | Uploads versioned .jar to Nexus OSS |
| 7 | **Docker Build** | Builds multi-stage image, tags with build number |
| 8 | **Deploy** | Runs container locally on port 8090 |

## Stack — 100% Free

| Tool | Role | Cost |
|------|------|------|
| [Gitea](https://gitea.io) | Self-hosted Git server | Free, OSS |
| [Jenkins LTS](https://www.jenkins.io) | CI/CD engine | Free, OSS |
| [SonarQube CE](https://www.sonarqube.org) | Code quality & coverage | Free, CE |
| [Nexus OSS](https://www.sonatype.com/products/nexus-repository) | Maven artifact repo | Free, OSS |
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | Container runtime | Free for personal use |

## Prerequisites (macOS)

- Docker Desktop ≥ 4.x with **at least 6 GB RAM** allocated  
  *(Settings → Resources → Memory)*
- Git
- That's it — Java and Maven run inside Docker

## Quick Start

```bash
# 1. Clone this repo
git clone <this-repo-url>
cd cicd-project

# 2. Check prerequisites and start the stack
chmod +x setup.sh scripts/*.sh
./setup.sh

# 3. Wait ~2 min, then run the bootstrap helper
./scripts/initial-config.sh

# 4. Complete the manual steps printed by the script
#    (Jenkins unlock, plugin installs, credential setup)

# 5. Copy Jenkinsfile + Dockerfile into your Java project root, then push:
git remote add origin http://localhost:3000/devops-org/my-app.git
git push -u origin main
# → Pipeline triggers automatically via webhook
```

## Connecting Your Java Project

1. Copy `Jenkinsfile` and `Dockerfile` from this repo into the **root** of your Maven project
2. Edit `Jenkinsfile` — update these two lines:
   ```groovy
   APP_NAME  = 'my-app'          // your Maven artifactId
   NEXUS_REPO = 'maven-releases' // or maven-snapshots
   ```
3. Edit `Dockerfile` — it works for any standard Spring Boot / Maven project as-is
4. Push to Gitea → pipeline fires automatically

## Jenkins Configuration Checklist

After the initial setup wizard:

- [ ] **Credentials** (Manage Jenkins → Credentials → Global):
  - `nexus-creds` — Username/Password (Nexus admin)
  - `gitea-token` — Username/Password (Gitea personal access token)
- [ ] **SonarQube server** (Manage Jenkins → System):
  - Name: `SonarQube` | URL: `http://sonarqube:9000`
- [ ] **Tools** (Manage Jenkins → Tools):
  - JDK: name `JDK-17`, auto-install from Adoptium
  - Maven: name `Maven-3.9`, auto-install
- [ ] **Multibranch Pipeline** job pointing to Gitea repo

## Ports

| Port | Service |
|------|---------|
| 3000 | Gitea web UI |
| 2222 | Gitea SSH |
| 8080 | Jenkins |
| 8081 | Nexus |
| 9000 | SonarQube |
| 8090 | Your deployed app |

## Stop / Reset

```bash
# Stop (keep data)
./scripts/teardown.sh

# Full reset (delete all data)
./scripts/teardown.sh --volumes
```

*Built as part of a DevOps practical course. All tools are open-source or free tier.*
