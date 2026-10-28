# Jenkins - Continuous Integration and Delivery

## Overview

Jenkins is an open-source automation server that enables developers to build, test, and deploy software reliably. It is the most widely adopted CI/CD tool in the industry, with an ecosystem of over 1,800 plugins that integrate with virtually every tool in the software development lifecycle.

### CI/CD Concepts

- **Continuous Integration (CI)** -- Automatically building and testing code every time a developer pushes changes, catching issues early
- **Continuous Delivery (CD)** -- Automatically preparing code for release to production after passing CI
- **Continuous Deployment** -- Automatically deploying every change that passes the pipeline to production

Jenkins implements all three through **pipelines** -- automated sequences of stages that take code from commit to production.

## Why Use Jenkins?

| Benefit | Description |
|---|---|
| **Mature and battle-tested** | 20+ years of development, used by thousands of organizations |
| **Extensible** | 1,800+ plugins for every tool and platform imaginable |
| **Pipeline as Code** | Define builds in version-controlled Jenkinsfiles |
| **Self-hosted** | Full control over your build infrastructure |
| **Distributed builds** | Scale horizontally with agent nodes |
| **Free and open source** | MIT licensed, no per-user or per-build fees |
| **Language agnostic** | Supports every programming language and framework |

## Installation

### Via Docker (Recommended)

```bash
# Create a Docker network
docker network create jenkins

# Run Jenkins with Docker-in-Docker support
docker run -d \
  --name jenkins \
  --restart unless-stopped \
  --network jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts-jdk17

# Get initial admin password
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### Via Docker Compose

```yaml
# docker-compose.yml
services:
  jenkins:
    image: jenkins/jenkins:lts-jdk17
    container_name: jenkins
    restart: unless-stopped
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - JAVA_OPTS=-Xmx2048m

volumes:
  jenkins_home:
```

### Native Installation (Ubuntu/Debian)

```bash
sudo apt update
sudo apt install fontconfig openjdk-17-jre

curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
  sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" | \
  sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt update
sudo apt install jenkins
sudo systemctl enable --now jenkins
```

### macOS

```bash
brew install jenkins-lts
brew services start jenkins-lts
# Access at http://localhost:8080
```

### Kubernetes via Helm

```bash
helm repo add jenkins https://charts.jenkins.io
helm repo update

helm install jenkins jenkins/jenkins \
  --namespace jenkins --create-namespace \
  --set controller.serviceType=LoadBalancer \
  --set persistence.size=50Gi

# Get admin password
kubectl exec -n jenkins svc/jenkins -c jenkins -- \
  cat /run/secrets/additional/chart-admin-password
```

### Initial Setup

1. Open `http://localhost:8080`
2. Enter the initial admin password
3. Install suggested plugins (or select specific ones)
4. Create the first admin user
5. Configure the Jenkins URL

## Pipeline as Code (Jenkinsfile)

The Jenkinsfile defines your build pipeline in code and lives in your repository root.

### Declarative Pipeline (Recommended)

```groovy
// Jenkinsfile
pipeline {
    agent any

    environment {
        DOCKER_REGISTRY = 'registry.example.com'
        APP_NAME        = 'myapp'
        DEPLOY_ENV      = "${env.BRANCH_NAME == 'main' ? 'production' : 'staging'}"
    }

    options {
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timestamps()
    }

    triggers {
        pollSCM('H/5 * * * *')   // Poll every 5 minutes
        // or use webhooks (preferred)
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                sh 'docker build -t ${DOCKER_REGISTRY}/${APP_NAME}:${BUILD_NUMBER} .'
            }
        }

        stage('Test') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        sh 'docker run --rm ${APP_NAME}:${BUILD_NUMBER} npm test'
                    }
                }
                stage('Lint') {
                    steps {
                        sh 'docker run --rm ${APP_NAME}:${BUILD_NUMBER} npm run lint'
                    }
                }
                stage('Security Scan') {
                    steps {
                        sh 'trivy image ${APP_NAME}:${BUILD_NUMBER}'
                    }
                }
            }
        }

        stage('Push Image') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                }
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'docker-registry',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                        echo $DOCKER_PASS | docker login $DOCKER_REGISTRY -u $DOCKER_USER --password-stdin
                        docker push ${DOCKER_REGISTRY}/${APP_NAME}:${BUILD_NUMBER}
                        docker tag ${DOCKER_REGISTRY}/${APP_NAME}:${BUILD_NUMBER} \
                                   ${DOCKER_REGISTRY}/${APP_NAME}:latest
                        docker push ${DOCKER_REGISTRY}/${APP_NAME}:latest
                    '''
                }
            }
        }

        stage('Deploy') {
            when {
                branch 'main'
            }
            input {
                message "Deploy to production?"
                ok "Yes, deploy it"
            }
            steps {
                sh "kubectl set image deployment/${APP_NAME} ${APP_NAME}=${DOCKER_REGISTRY}/${APP_NAME}:${BUILD_NUMBER}"
            }
        }
    }

    post {
        success {
            slackSend(channel: '#deployments', color: 'good',
                message: "SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}")
        }
        failure {
            slackSend(channel: '#deployments', color: 'danger',
                message: "FAILURE: ${env.JOB_NAME} #${env.BUILD_NUMBER}")
        }
        always {
            cleanWs()
        }
    }
}
```

### Declarative vs Scripted Pipelines

| Aspect | Declarative | Scripted |
|---|---|---|
| **Syntax** | Structured, opinionated | Full Groovy flexibility |
| **Learning curve** | Lower | Higher |
| **Error handling** | Built-in `post` blocks | Manual `try/catch/finally` |
| **Validation** | Syntax checked before execution | Runtime errors only |
| **Recommended for** | Most use cases | Complex conditional logic |

### Scripted Pipeline Example

```groovy
// Jenkinsfile (Scripted)
node {
    try {
        stage('Checkout') {
            checkout scm
        }

        stage('Build') {
            def image = docker.build("myapp:${env.BUILD_NUMBER}")

            stage('Test') {
                image.inside {
                    sh 'npm test'
                }
            }

            if (env.BRANCH_NAME == 'main') {
                stage('Push') {
                    docker.withRegistry('https://registry.example.com', 'docker-creds') {
                        image.push()
                        image.push('latest')
                    }
                }
            }
        }
    } catch (e) {
        currentBuild.result = 'FAILURE'
        throw e
    } finally {
        cleanWs()
    }
}
```

## Shared Libraries

Shared libraries let you extract common pipeline logic into a reusable library stored in a separate Git repository.

### Library Structure

```
vars/
  buildDockerImage.groovy    # Global variables / functions
  deployToK8s.groovy
  notifySlack.groovy
src/
  org/
    example/
      Docker.groovy          # Groovy classes
resources/
  templates/
    deployment.yaml          # Resource files
```

### Defining a Shared Step

```groovy
// vars/buildDockerImage.groovy
def call(Map config = [:]) {
    def registry = config.registry ?: 'registry.example.com'
    def imageName = config.imageName ?: env.JOB_NAME
    def tag = config.tag ?: env.BUILD_NUMBER

    sh """
        docker build -t ${registry}/${imageName}:${tag} .
        docker push ${registry}/${imageName}:${tag}
    """

    return "${registry}/${imageName}:${tag}"
}
```

```groovy
// vars/notifySlack.groovy
def call(String status = 'SUCCESS') {
    def color = status == 'SUCCESS' ? 'good' : 'danger'
    slackSend(
        channel: '#ci-cd',
        color: color,
        message: "${status}: ${env.JOB_NAME} #${env.BUILD_NUMBER} (<${env.BUILD_URL}|Open>)"
    )
}
```

### Using the Shared Library

```groovy
// Jenkinsfile
@Library('my-shared-library') _

pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                script {
                    def image = buildDockerImage(
                        imageName: 'myapp',
                        tag: env.BUILD_NUMBER
                    )
                }
            }
        }
    }
    post {
        success { notifySlack('SUCCESS') }
        failure { notifySlack('FAILURE') }
    }
}
```

### Configuring the Library in Jenkins

Go to **Manage Jenkins > System > Global Pipeline Libraries**:
- Name: `my-shared-library`
- Default version: `main`
- Source: Git, repository URL

## Plugins Ecosystem

### Essential Plugins

| Plugin | Purpose |
|---|---|
| **Pipeline** | Pipeline as Code support (installed by default) |
| **Git** | Git SCM integration |
| **Docker Pipeline** | Build and use Docker images in pipelines |
| **Blue Ocean** | Modern UI for pipelines |
| **Credentials Binding** | Securely inject credentials into builds |
| **Slack Notification** | Send notifications to Slack |
| **JUnit** | Test result reporting |
| **Cobertura / JaCoCo** | Code coverage reporting |
| **GitHub Branch Source** | Automatic pipeline creation for GitHub repos |
| **Configuration as Code (JCasC)** | Configure Jenkins via YAML |
| **Kubernetes** | Dynamic agents on Kubernetes |
| **OWASP Dependency-Check** | Security vulnerability scanning |

### Jenkins Configuration as Code (JCasC)

Define Jenkins configuration in YAML instead of the UI:

```yaml
# jenkins.yaml
jenkins:
  systemMessage: "Jenkins configured via JCasC"
  numExecutors: 0    # Controller should not run builds
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: admin
          password: "${ADMIN_PASSWORD}"

  authorizationStrategy:
    roleBased:
      roles:
        global:
          - name: admin
            permissions:
              - "Overall/Administer"
            entries:
              - user: admin

unclassified:
  location:
    url: https://jenkins.example.com/
  slackNotifier:
    teamDomain: myteam
    tokenCredentialId: slack-token
```

## Best Practices

### Pipeline Design

1. **Keep Jenkinsfiles in the repository** -- version control your pipeline alongside your code
2. **Use declarative pipelines** -- simpler, more maintainable, and validated before execution
3. **Parallelize where possible** -- run independent tasks (unit tests, lint, security scan) in parallel
4. **Fail fast** -- put quick checks (lint, compile) before slow ones (integration tests)
5. **Use shared libraries** -- avoid duplicating pipeline logic across repositories
6. **Add timeouts** -- prevent hung builds from consuming resources indefinitely

### Security

7. **Never hardcode credentials** -- use the Credentials plugin and `withCredentials` blocks
8. **Limit plugin installations** -- each plugin increases the attack surface
9. **Keep Jenkins and plugins updated** -- security vulnerabilities are regularly discovered
10. **Use Role-Based Access Control** -- restrict who can configure jobs and view builds
11. **Run builds on agents, not the controller** -- set controller executors to 0

### Infrastructure

12. **Use ephemeral agents** -- Kubernetes or Docker agents that spin up per-build
13. **Back up `JENKINS_HOME` regularly** -- it contains all job configurations and history
14. **Use JCasC** -- reproducible Jenkins configuration, stored in version control
15. **Monitor Jenkins** -- track queue length, build times, and agent availability

### Build Hygiene

16. **Clean workspaces** -- use `cleanWs()` in `post.always`
17. **Archive artifacts selectively** -- do not archive large or unnecessary files
18. **Set build retention policies** -- use `buildDiscarder` to prevent disk exhaustion

## Multibranch Pipeline

Automatically creates pipelines for every branch and PR in a repository.

```
Manage Jenkins > New Item > Multibranch Pipeline
  Branch Sources: GitHub
    Repository: org/repo
    Behaviours:
      - Discover branches
      - Discover pull requests
  Build Configuration:
    Mode: by Jenkinsfile
    Script Path: Jenkinsfile
```

Jenkins will scan the repository and create a pipeline for every branch containing a `Jenkinsfile`.

## Resources

- [Official Jenkins Documentation](https://www.jenkins.io/doc/)
- [Jenkins Pipeline Syntax Reference](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Jenkins Plugin Index](https://plugins.jenkins.io/)
- [Jenkins Configuration as Code](https://www.jenkins.io/projects/jcasc/)
- [Jenkins Shared Libraries](https://www.jenkins.io/doc/book/pipeline/shared-libraries/)
- [Blue Ocean Documentation](https://www.jenkins.io/doc/book/blueocean/)
- [Jenkins Best Practices (CloudBees)](https://www.cloudbees.com/blog/jenkins-best-practices)
- [Jenkins Kubernetes Plugin](https://plugins.jenkins.io/kubernetes/)
