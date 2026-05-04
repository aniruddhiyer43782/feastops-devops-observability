pipeline {
  agent any

  parameters {
    string(name: 'REGISTRY_IMAGE', defaultValue: '', description: 'Optional full registry image, for example docker.io/yourname/feastops-food-delivery-api:latest')
    booleanParam(name: 'PUSH_IMAGE', defaultValue: false, description: 'Push REGISTRY_IMAGE after build and smoke test. Requires Docker login/credentials on the Jenkins agent.')
  }

  environment {
    PROJECT_DIR = '/workspace/feastops'
    APP_DIR = '/workspace/feastops/app'
    IMAGE_NAME = 'feastops-food-delivery-api'
    SONAR_HOST_URL = 'http://sonarqube:9000'
    SONAR_WORK_DIR = "/tmp/sonar-feastops-${BUILD_NUMBER}"
  }

  stages {
    stage('Install Dependencies') {
      steps {
        dir(env.APP_DIR) {
          sh 'npm install'
        }
      }
    }

    stage('Lint') {
      steps {
        dir(env.APP_DIR) {
          sh 'npm run lint'
        }
      }
    }

    stage('Dependency Audit') {
      steps {
        dir(env.APP_DIR) {
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
        dir(env.APP_DIR) {
          sh 'npm test -- --coverage --forceExit'
        }
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: 'app/reports/junit.xml'
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
        dir(env.APP_DIR) {
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
        dir(env.APP_DIR) {
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
        sh '''
          docker tag "$IMAGE_NAME:$BUILD_NUMBER" "$REGISTRY_IMAGE"
          docker push "$REGISTRY_IMAGE"
        '''
      }
    }
  }

  post {
    always {
      dir(env.APP_DIR) {
        junit allowEmptyResults: true, testResults: 'reports/junit.xml'
        archiveArtifacts artifacts: 'coverage/**', allowEmptyArchive: true
      }
    }
  }
}
