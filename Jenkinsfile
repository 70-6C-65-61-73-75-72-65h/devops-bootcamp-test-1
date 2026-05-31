@Library('jenkins-shared-library-1')_

pipeline {
  agent {
    label 'buildkit'
  }
  environment {
    BUILDKIT_HOST = 'tcp://buildkit:1234'
    REPORT_DIR = 'security-reports' 
  }
  parameters {
    // booleanParam(name: "RUN_MVN_CHECKS", defaultValue: false, description: "Run maven code source checks")
    string(name: "REGISTRY", defaultValue: 'docker.io', description: "IMAGE REGISTRY")
    string(name: "IMAGE_REPO", defaultValue: 'myprojectsthebest/devops-bootcamp-demo', description: "IMAGE REPO")
    string(name: "IMAGE_TAG", defaultValue: 'jmaic-1.0', description: "IMAGE TAG")
    string(name: "DOCKERFILE_PATH", defaultValue: '.', description: "Dockerfile path")
  }
  options {
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '10'))
    timestamps()
    timeout(time: 45, unit: "MINUTES")
  }
  stages {
    stage("Checkout and Init"){
      steps {
        checkout scm
        sh '''
          set -eux
          mkdir -p "$REPORT_DIR"
          git rev-parse --short=12  HEAD  > .git-sha-short
        '''
        script { 
          def lastCommitSha = readFile('.git-sha-short')
          env.LAST_COMMIT = "${lastCommitSha}"
          echo "LAST COMMIT: $LAST_COMMIT"
          env.REGISTRY = "${params.REGISTRY}"
          env.DOCKERFILE_PATH = "${params.DOCKERFILE_PATH}"
          env.IMAGE_REPO = "${params.IMAGE_REPO}"
          env.IMAGE_NAME = "$REGISTRY/$IMAGE_REPO:${params.IMAGE_TAG}"
          echo "IMAGE_NAME: ${env.IMAGE_NAME}"
          echo "IMAGE_REPO: ${env.IMAGE_REPO}"
          echo "REGISTRY: ${env.REGISTRY}"
        }
      }
    }

    stage("Tool Sanity Check"){
      steps{
        sh '''
          set -eux;
          jq --version
          trivy --version
          syft version
          grype version
          hadolint --version
          java -version
          mvn --version
          buildctl --addr $BUILDKIT_HOST debug workers
        '''
      }
    }

    stage("Dockerfile Lint"){
      steps {
        sh '''
          set -eux;
          if [ -f "$DOCKERFILE_PATH/Dockerfile" ]; then
            hadolint "$DOCKERFILE_PATH/Dockerfile" | tee "$REPORT_DIR/hadolint.txt"
          else
            echo "No Dockerfile Found, Skipping Hadolint" | tee "$REPORT_DIR/hadolint.txt"
          fi
        '''
      }
    }

    stage("Build source code and run junit tests"){
      steps{
        sh '''
          set -eux;
          mvn -B -ntp clean verify
        '''
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: '**/target/surefire-reports/*.xml,**/target/failsafe-reports/*.xml'
          archiveArtifacts artifacts: '**/target/*.jar', allowEmptyArchive: true
        }
      }
    }

    stage("Build Image and Push to Remote Regisrty"){
      steps {
        withCredentials([usernamePassword(
          credentialsId: "dockerhub-creds",
          usernameVariable: "DOCKERHUB_USER",
          passwordVariable: "DOCKERHUB_PASSWORD")]){
            sh '''
              set -euox pipefail

              export DOCKER_CONFIG="$(mktemp -d)"

              cleanup(){
                rc=$?
                rm -rf "$DOCKER_CONFIG"
                exit "$rc"
              }

              trap cleanup EXIT INT TERM HUP

              set +x

              AUTH=$(printf '%s:%s' "$DOCKERHUB_USER" "$DOCKERHUB_PASSWORD" | base64 | tr -d '\\n')

              jq -n \
                --arg auth "$AUTH" \
                --arg registry "$REGISTRY" \
                '{auths: {($registry): {auth: $auth}}}' \
              > "$DOCKER_CONFIG/config.json"

              unset AUTH

              set -x

              buildctl --addr $BUILDKIT_HOST build \
                --frontend dockerfile.v0 \
                --local context=. \
                --local dockerfile="$DOCKERFILE_PATH" \
                --output type=image,name="$IMAGE_NAME",push=true
            '''.stripIndent()
        }
      }
    }

    stage("Image SBOM - SYFT"){
      steps {
        withCredentials([usernamePassword(
          credentialsId: "dockerhub-creds",
          usernameVariable: "DOCKERHUB_USER",
          passwordVariable: "DOCKERHUB_PASSWORD")]){
            catchError {
              sh '''
                set -eux;
                export SYFT_REGISTRY_AUTH_AUTHORITY="$REGISTRY"
                export SYFT_REGISTRY_AUTH_USERNAME="$DOCKERHUB_USER"
                export SYFT_REGISTRY_AUTH_PASSWORD="$DOCKERHUB_PASSWORD"

                syft registry:"$IMAGE_NAME" \
                  -o cyclonedx-json="$REPORT_DIR/image-sbom.cdx.json" \
                  -o spdx-json="$REPORT_DIR/image-sbom.spdx.json" \
              '''
            }
          }
      }
    }

    stage("Image Vulnerability Scan - GRYPE"){
      steps {
        catchError {
          sh '''
            set -eux;

            grype sbom:"$REPORT_DIR/image-sbom.cdx.json" \
              -o json > "$REPORT_DIR/grype-image.json"

            grype sbom:"$REPORT_DIR/image-sbom.cdx.json" \
              --fail-on high
          '''
        }
      }
    }

    stage("Image Scan - TRIVY"){
      steps {
        withCredentials([usernamePassword(
          credentialsId: "dockerhub-creds",
          usernameVariable: "DOCKERHUB_USER",
          passwordVariable: "DOCKERHUB_PASSWORD")]){
            catchError {
              sh '''
                set -eux;
                export TRIVY_USERNAME="$NEXUS_USER"
                export TRIVY_PASSWORD="$NEXUS_PASSWORD"

                trivy image  \
                  --image-src remote \
                  --scanners vuln,secret,misconfig,license \
                  --image-config-scanners misconfig,secret \
                  --format json \
                  --output "$REPORT_DIR/trivy-image.json" \
                  "$IMAGE_NAME"

                trivy image  \
                  --image-src remote \
                  --scanners vuln,secret,misconfig \
                  --image-config-scanners misconfig,secret \
                  --format json \
                  --severity HIGH,CRITICAL \
                  --exit-code 1 \
                  "$IMAGE_NAME"
              '''
            }
          }
      }
    }
  }
      post {
      always {
        archiveArtifacts artifacts: '$REPORT_DIR/**/*', allowEmptyArchive: true
      }
      success {
        echo 'Image successfully built and scanned: $IMAGE_NAME for such commmit: $LAST_COMMIT'
      } 
    }
}