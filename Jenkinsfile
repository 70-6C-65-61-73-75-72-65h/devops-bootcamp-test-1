@Library('jenkins-shared-library-1')_

def registryDockerConfigMap = ['docker.io': 'https://index.docker.io/v1/']

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
    string(name: "REPO_CREDS_ID", defaultValue: 'dockerhub-creds', description: "Dockerfile path")
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
          echo "LAST COMMIT: ${env.LAST_COMMIT}"
          env.REGISTRY = "${params.REGISTRY}"
          env.REPO_CREDS_ID = "${params.REPO_CREDS_ID}"
          env.DOCKERFILE_PATH = "${params.DOCKERFILE_PATH}"
          env.IMAGE_REPO = "${params.IMAGE_REPO}"
          env.IMAGE_NAME = "${env.REGISTRY}/${env.IMAGE_REPO}:${params.IMAGE_TAG}"
          echo "IMAGE_NAME: ${env.IMAGE_NAME}"
          echo "IMAGE_REPO: ${env.IMAGE_REPO}"
          echo "REGISTRY: ${env.REGISTRY}"
          env.REGISTRY_DOCKER_CONFIG=registryDockerConfigMap["${env.REGISTRY}"]  
            ? registryDockerConfigMap["${env.REGISTRY}"] 
            : "${env.REGISTRY}"
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
        script{
          dockerfileLint()
        } 
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
        script {
          buildAndPushImage(env.REPO_CREDS_ID)
        }
       }
    }

    stage("Image SBOM - SYFT"){
      steps {
        withCredentials([usernamePassword(
          credentialsId: "$REPO_CREDS_ID",
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
        script {
          trivyImageScan(env.REPO_CREDS_ID)
          trivyImageScan(env.REPO_CREDS_ID, 'gate')
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
