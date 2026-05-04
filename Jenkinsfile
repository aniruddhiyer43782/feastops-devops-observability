pipeline {
  agent any

  parameters {
    string(name: 'REGISTRY_IMAGE', defaultValue: 'ghcr.io/aniruddhiyer43782/feastops-food-delivery-api:jenkins', description: 'Full registry image pushed after tests, Quality Gate, and image smoke test')
    string(name: 'REGISTRY_CREDENTIALS_ID', defaultValue: 'registry-credentials', description: 'Jenkins username/password credential used for docker login')
    booleanParam(name: 'PUSH_IMAGE', defaultValue: true, description: 'Push REGISTRY_IMAGE after build, tests, SonarQube Quality Gate, and image smoke test')
  }

  triggers {
    githubPush()
  }

  environment {
    PROJECT_DIR = '/workspace/feastops'
    APP_DIR = '/workspace/feastops/app'
    CI_ROOT = "/tmp/feastops-ci-${BUILD_NUMBER}"
    CI_APP_DIR = "/tmp/feastops-ci-${BUILD_NUMBER}/app"
    IMAGE_NAME = 'feastops-food-delivery-api'
    SONAR_HOST_URL = 'http://sonarqube:9000'
    SONAR_WORK_DIR = "/tmp/sonar-feastops-${BUILD_NUMBER}"
  }

  stages {
    stage('Prepare CI Workspace') {
      steps {
        sh '''
          rm -rf "$CI_ROOT"
          mkdir -p "$CI_APP_DIR"
          cp "$APP_DIR/package.json" "$APP_DIR/package-lock.json" "$APP_DIR/sonar-project.properties" "$APP_DIR/eslint.config.js" "$APP_DIR/Dockerfile" "$CI_APP_DIR/"
          cp -R "$APP_DIR/src" "$APP_DIR/public" "$APP_DIR/test" "$APP_DIR/scripts" "$CI_APP_DIR/"
        '''
      }
    }

    stage('Install Dependencies') {
      steps {
        dir(env.CI_APP_DIR) {
          sh 'npm ci --cache /tmp/npm-cache-feastops'
        }
      }
    }

    stage('Lint') {
      steps {
        dir(env.CI_APP_DIR) {
          sh 'npm run lint'
        }
      }
    }

    stage('Dependency Audit') {
      steps {
        dir(env.CI_APP_DIR) {
          sh '''
            npm audit --omit=dev --audit-level=high || {
              echo "Dependency audit could not complete or found high production dependency risk."
              echo "Continuing because this local demo should not depend on npm audit API availability."
            }
          '''
        }
      }
    }

    stage('Test') {
      steps {
        dir(env.CI_APP_DIR) {
          sh '''
            npm test -- --coverage --forceExit
            rm -rf "$APP_DIR/coverage" "$APP_DIR/reports"
            cp -R coverage reports "$APP_DIR/"
          '''
        }
      }
    }

    stage('Application Smoke Test') {
      steps {
        sh 'curl -fsS http://app:3000/health'
      }
    }

    stage('SonarQube Scan') {
      steps {
        dir(env.CI_APP_DIR) {
          withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_TOKEN')]) {
            sh '''
              rm -rf "$SONAR_WORK_DIR"
              npx sonar \
                -Dsonar.host.url=$SONAR_HOST_URL \
                -Dsonar.token=$SONAR_TOKEN \
                -Dsonar.working.directory=$SONAR_WORK_DIR
            '''
          }
        }
      }
    }

    stage('Quality Gate') {
      steps {
        dir(env.CI_APP_DIR) {
          withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_TOKEN')]) {
            sh 'node scripts/check-sonar-quality-gate.js "$SONAR_WORK_DIR/report-task.txt"'
          }
        }
      }
    }

    stage('Docker Build') {
      steps {
        sh 'docker build -t $IMAGE_NAME:$BUILD_NUMBER $PROJECT_DIR/app'
        sh 'docker tag $IMAGE_NAME:$BUILD_NUMBER $IMAGE_NAME:latest'
        sh 'docker tag $IMAGE_NAME:$BUILD_NUMBER $IMAGE_NAME:jenkins'
      }
    }

    stage('Docker Image Smoke Test') {
      steps {
        sh '''
          container="feastops-smoke-$BUILD_NUMBER"
          docker rm -f "$container" >/dev/null 2>&1 || true
          docker run -d --name "$container" --network devops-observability-project_devops-net "$IMAGE_NAME:$BUILD_NUMBER"

          for attempt in $(seq 1 20); do
            if docker exec "$container" node -e "require('http').get('http://localhost:3000/health', r => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"; then
              docker rm -f "$container"
              exit 0
            fi
            sleep 2
          done

          docker logs "$container"
          docker rm -f "$container"
          exit 1
        '''
      }
    }

    stage('Publish Registry Image') {
      when {
        expression {
          return params.PUSH_IMAGE && params.REGISTRY_IMAGE?.trim()
        }
      }
      steps {
        withCredentials([usernamePassword(credentialsId: "${params.REGISTRY_CREDENTIALS_ID}", usernameVariable: 'REGISTRY_USERNAME', passwordVariable: 'REGISTRY_PASSWORD')]) {
          sh '''
            registry_host="$(echo "$REGISTRY_IMAGE" | awk -F/ '{print $1}')"
            case "$registry_host" in
              *.*|*:*) ;;
              *) registry_host="docker.io" ;;
            esac

            echo "$REGISTRY_PASSWORD" | docker login "$registry_host" --username "$REGISTRY_USERNAME" --password-stdin
            docker tag "$IMAGE_NAME:$BUILD_NUMBER" "$REGISTRY_IMAGE"
            docker push "$REGISTRY_IMAGE"
            docker logout "$registry_host"
            echo "Published $REGISTRY_IMAGE from $IMAGE_NAME:$BUILD_NUMBER"
          '''
        }
      }
    }
  }

  post {
    always {
      dir(env.APP_DIR) {
        junit allowEmptyResults: true, testResults: 'reports/junit.xml'
        archiveArtifacts artifacts: 'coverage/**', allowEmptyArchive: true
      }
      sh 'rm -rf "$CI_ROOT" "$SONAR_WORK_DIR" || true'
    }
  }
}
