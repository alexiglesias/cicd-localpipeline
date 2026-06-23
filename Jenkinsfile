// ─────────────────────────────────────────────────────────────────────────────
// Jenkinsfile — CI/CD Pipeline
// Stack: Gitea → Jenkins → SonarQube CE → Nexus OSS → Docker (local)
//
// DROP THIS FILE at the root of your Java/Maven project.
// ─────────────────────────────────────────────────────────────────────────────

pipeline {
    agent any

    // ── Tool aliases (configure these names in Jenkins > Global Tool Config) ──
    tools {
        maven 'Maven-3.9'
        jdk   'JDK-17'
    }

    // ── Environment variables ─────────────────────────────────────────────────
    environment {
        // ── Your app ──────────────────────────────────────────────────────────
        APP_NAME        = 'my-app'                // change to your artifact id
        APP_VERSION     = "${BUILD_NUMBER}"        // auto-increments with every build

        // ── Docker ────────────────────────────────────────────────────────────
        DOCKER_IMAGE    = "${APP_NAME}:${APP_VERSION}"
        DOCKER_LATEST   = "${APP_NAME}:latest"

        // ── Nexus ─────────────────────────────────────────────────────────────
        NEXUS_URL       = 'http://nexus:8081'
        NEXUS_REPO      = 'maven-releases'        // or maven-snapshots
        NEXUS_CREDS     = credentials('nexus-creds') // Jenkins credential id

        // ── SonarQube ─────────────────────────────────────────────────────────
        SONAR_PROJECT   = "${APP_NAME}"
    }

    // ── Pipeline options ──────────────────────────────────────────────────────
    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 20, unit: 'MINUTES')
    }

    stages {

        // ── 1. Checkout ───────────────────────────────────────────────────────
        stage('Checkout') {
            steps {
                checkout scm
                echo "Branch: ${env.GIT_BRANCH} | Commit: ${env.GIT_COMMIT[0..6]}"
            }
        }

        // ── 2. Build ──────────────────────────────────────────────────────────
        stage('Build') {
            steps {
                sh 'mvn clean package -DskipTests'
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
        }

        // ── 3. Unit Tests ─────────────────────────────────────────────────────
        stage('Test') {
            steps {
                sh 'mvn test'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }

        // ── 4. Code Quality Gate ──────────────────────────────────────────────
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {   // matches Jenkins system config name
                    sh """
                        mvn sonar:sonar \
                          -Dsonar.projectKey=${SONAR_PROJECT} \
                          -Dsonar.projectName='${APP_NAME}' \
                          -Dsonar.java.coveragePlugin=jacoco \
                          -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml
                    """
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    // Blocks the pipeline until SonarQube returns pass/fail
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        // ── 5. Publish to Nexus ───────────────────────────────────────────────
        stage('Publish to Nexus') {
            steps {
                nexusArtifactUploader(
                    nexusVersion: 'nexus3',
                    protocol: 'http',
                    nexusUrl: 'nexus:8081',
                    groupId: 'com.yourcompany',       // match your pom.xml groupId
                    version: "${APP_VERSION}",
                    repository: "${NEXUS_REPO}",
                    credentialsId: 'nexus-creds',
                    artifacts: [[
                        artifactId: "${APP_NAME}",
                        classifier: '',
                        file: "target/${APP_NAME}-*.jar",
                        type: 'jar'
                    ]]
                )
            }
        }

        // ── 6. Build Docker Image ─────────────────────────────────────────────
        stage('Docker Build') {
            steps {
                sh """
                    docker build \
                      --build-arg JAR_FILE=target/${APP_NAME}-*.jar \
                      -t ${DOCKER_IMAGE} \
                      -t ${DOCKER_LATEST} \
                      .
                """
            }
        }

        // ── 7. Deploy (local Docker) ──────────────────────────────────────────
        stage('Deploy') {
            steps {
                sh """
                    # Stop & remove previous container if running
                    docker rm -f ${APP_NAME} 2>/dev/null || true

                    # Run new container
                    docker run -d \
                      --name ${APP_NAME} \
                      --network cicd-project_cicd-net \
                      -p 8090:8080 \
                      ${DOCKER_IMAGE}

                    echo "App deployed → http://localhost:8090"
                """
            }
        }
    }

    // ── Post-pipeline notifications ───────────────────────────────────────────
    post {
        success {
            echo "✅ Pipeline passed — build #${BUILD_NUMBER} deployed."
        }
        failure {
            echo "❌ Pipeline failed at stage. Check logs above."
        }
        always {
            cleanWs()   // wipe workspace to save disk
        }
    }
}
