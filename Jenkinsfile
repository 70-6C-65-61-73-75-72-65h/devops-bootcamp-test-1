@Library('jenkins-shared-library-1')_

pipeline {
  agent {
    label 'buildkit'
  }
  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '10'))
    timeout(time: 45, unit: 'MINUTES')
  }
  environment {
    BUILDKIT_HOST = 'tcp://buildkit:1234'
    REGISTRY = 'nexus:8083'
    IMAGE_REPO = 'nexus:8083/devops-bootcamp-demo:jmaic-1.0'
    REPORT_DIR = 'security-reports'

  }
  stages{
    stage("Checkout"){
      steps {
        checkout scm
        sh """
          set -eux
          mkdir -p $REPORT_DIR
          git rev-parse --short=12 HEAD > .git-short-sha
        """
        script {
          def shortSha = readFile('.git-short-sha').trim()
          env.IMAGE_TAG = "${env.BUILD_NUMBER}-${shortSha}" 
          env.IMAGE = "${env.IMAGE_REPO}:${env.IMAGE_TAG}"
          echo "IMAGE: ${env.IMAGE}"
        }
      }
    }
    stage("Tool Sanity Check"){
      steps{
        sh """
          set -eux
          java -version
          mvn --version
          buildctl --addr \"$BUILDKIT_HOST\" debug workers
          syft version
          grype version
          gitleaks version
          trivy --version
          semgrep --version
          osv-scanner --version
          hadolint --version
        """
      }
    }

    stage('Secrets scan') {
      steps {
        sh """
          set -eux

          gitleaks dir . \
            --no-banner \
            --redact \
            --report-format json \
            --report-path \"$REPORT_DIR/gitleaks-dir.json\"
        """
      }
    }

    stage('Dockerfile lint') {
      steps {
        sh """
          set -eux

          if [ -f Dockerfile ]; then
            hadolint Dockerfile | tee \"$REPORT_DIR/hadolint.txt\"
          else
            echo \"Dockerfile not found, skipping hadolint\" | tee \"$REPORT_DIR/hadolint.txt\"
          fi
        """
      }
    }

    stage('SAST - Semgrep') {
      steps {
        sh """
          set -eux

          semgrep scan \
            --metrics=off \
            --config=p/java \
            --config=p/owasp-top-ten \
            --sarif \
            --output \"$REPORT_DIR/semgrep.sarif\" \
            --error .
        """
      }
    }
    stage('Maven test + package') {
      steps {
        sh """
          set -eux

          mvn -B -ntp clean verify
        """
      }

      post {
        always {
          junit allowEmptyResults: true, testResults: '**/target/surefire-reports/*.xml,**/target/failsafe-reports/*.xml'
          archiveArtifacts artifacts: '**/target/*.jar', allowEmptyArchive: true
        }
      }
    }
    
    stage('Maven dependency SBOM') {
      steps {
        sh """
          set -eux

          mvn -B -ntp org.cyclonedx:cyclonedx-maven-plugin:makeAggregateBom \
            -DoutputFormat=json \
            -DoutputName=maven-sbom

          cp target/maven-sbom.json \"$REPORT_DIR/maven-sbom.cdx.json\"
        """
      }
    }

    stage('Maven dependency scan') {
      steps {
        catchError(buildResult: "SUCCESS", stageResult:"FAILURE"){
        sh """
          # OSV scan по source/dependency manifests
          set -eux
          osv-scanner scan source \
            --recursive \
            --format=html \
            --output-file=\"$REPORT_DIR/osv-source.html\" \
            .
        """
        }
        catchError(buildResult: "SUCCESS", stageResult:"FAILURE"){
        sh """
         set -eux
          osv-scanner scan source \
            --recursive \
            --format=json \
            --output-file=\"$REPORT_DIR/osv-source.json\" \
            .
        """
        }
        catchError(buildResult: "SUCCESS", stageResult:"FAILURE"){
        sh """
          set -eux
          # Grype scan по Maven CycloneDX SBOM
          grype sbom:\"$REPORT_DIR/maven-sbom.cdx.json\" \
            -o json > \"$REPORT_DIR/grype-maven-sbom.json\"
    
          # Gate: HIGH/CRITICAL ломают билд
          grype sbom:\"$REPORT_DIR/maven-sbom.cdx.json\" \
            --fail-on high
        """
        }
      }
    }

    // stage('OWASP Dependency-Check') {
    //   steps {
    //     catchError(buildResult: "SUCCESS", stageResult:"FAILURE"){
    //     sh """
    //       set -eux

    //       mvn -B -ntp org.owasp:dependency-check-maven:check \
    //         -Dformat=ALL \
    //         -DfailBuildOnCVSS=9 \
    //         -DoutputDirectory=\"$REPORT_DIR/dependency-check\"
    //     """
    //   }
    //   }
    // }

    stage('Build and push image with Buildkit'){
      steps{
        withCredentials([
          usernamePassword(
            credentialsId:'nexus-local-creds',
            usernameVariable:'NEXUS_USER',
            passwordVariable: 'NEXUS_PASSWORD')]){
          sh '''
            set -euox pipefail
 
            export DOCKER_CONFIG="$(mktemp -d)"

            cleanup(){
              rc=$?
              rm -rf "$DOCKER_CONFIG"
              exit "$rc"
            }

            trap cleanup EXIT INT TERM HUP

            umask 077
            mkdir -p "$DOCKER_CONFIG"

            set +x
            AUTH=$(printf '%s:$s' "$NEXUS_USER" "$NEXUS_PASSWORD" | base64 | tr -d '\\n')
            cat> "$DOCKER_CONFIG/config.json" <<EOF
            {
              "auths": {
                "$REGISTRY": {
                  "auth": "$AUTH"
                }
              }
            }
            EOF
            set -x

            buildctl --addr "$BUILDKIT_HOST" build \
              --frontend dockerfile.v0 \
              --local context=. \
              --local dockerfile=. \
              --output type=image,name="$IMAGE",push=true

          '''.stripIndent()
        }
      }
    }
    
    stage('Image SBOM - Syft') {
      steps {
        catchError(buildResult: "SUCCESS", stageResult:"FAILURE"){
        withCredentials([
          usernamePassword(
            credentialsId:'nexus-local-creds',
            usernameVariable:'NEXUS_USER',
            passwordVariable: 'NEXUS_PASSWORD'
          )
        ]) {
          sh '''
            set -eux

            export SYFT_REGISTRY_AUTH_AUTHORITY="$REGISTRY"
            export SYFT_REGISTRY_AUTH_USERNAME="$NEXUS_USER"
            export SYFT_REGISTRY_AUTH_PASSWORD="$NEXUS_PASSWORD"

            syft "$IMAGE" \
              -o cyclonedx-json="$REPORT_DIR/image-sbom.cdx.json" \
              -o spdx-json="$REPORT_DIR/image-sbom.spdx.json"
          '''
        }
      }
      }
    }

    stage('Image vulnerability scan - Grype') {
      steps {
      catchError(buildResult: "SUCCESS", stageResult:"FAILURE"){
        withCredentials([
          usernamePassword(
            credentialsId:'nexus-local-creds',
            usernameVariable:'NEXUS_USER',
            passwordVariable: 'NEXUS_PASSWORD'
          )
        ]) {
          sh '''
            set -eux

            export GRYPE_REGISTRY_AUTH_AUTHORITY="$REGISTRY"
            export GRYPE_REGISTRY_AUTH_USERNAME="$NEXUS_USER"
            export GRYPE_REGISTRY_AUTH_PASSWORD="$NEXUS_PASSWORD"

            grype sbom:"$REPORT_DIR/image-sbom.cdx.json" \
              -o json > "$REPORT_DIR/grype-image.json"

            grype sbom:"$REPORT_DIR/image-sbom.cdx.json" \
              --fail-on high
          '''
        }
      }
      }
    }

    stage('Image scan - Trivy') {
      steps {
        withCredentials([
          usernamePassword(
            credentialsId:'nexus-local-creds',
            usernameVariable:'NEXUS_USER',
            passwordVariable: 'NEXUS_PASSWORD'
          )
        ]) {
          catchError(buildResult: "SUCCESS", stageResult:"FAILURE"){
          sh '''
            set -eux

            export TRIVY_USERNAME="$NEXUS_USER"
            export TRIVY_PASSWORD="$NEXUS_PASSWORD"

            trivy image \
              --image-src "$REGISTRY" \
              --scanners vuln,secret,misconfig,license \
              --image-config-scanners misconfig,secret \
              --format json \
              --output "$REPORT_DIR/trivy-image.json" \
              "$IMAGE"
          '''
          }
          catchError(buildResult: "SUCCESS", stageResult:"FAILURE"){
          sh '''
            set -eux
            export TRIVY_USERNAME="$NEXUS_USER"
            export TRIVY_PASSWORD="$NEXUS_PASSWORD"

            trivy image \
              --image-src registry \
              --scanners vuln,secret,misconfig \
              --image-config-scanners misconfig,secret \
              --severity HIGH,CRITICAL \
              --exit-code 1 \
              "$IMAGE"
          '''
          }
        }
      }
    }

    stage('Image scan - OSV') {
      steps {
        sh '''
          set -eux

          osv-scanner scan image \
            --format=json \
            --output="$REPORT_DIR/osv-image.json" \
            "$IMAGE"
        '''
      }
    }

  }
  post {
    always {
      archiveArtifacts artifacts: "$REPORT_DIR/**/*", allowEmptyArchive: true
      sh 'rm -rf "$WORKSPACE/.docker-ci" 2>/dev/null || true'
    }
    success{
      echo "Image built and scanned: ${env.IMAGE_TAG}"
    }
  }
}

// // library identifier: 'jenkins-shared-library@master', retriever: modernSCM(
// //   [$class: 'GitSCMSource', remote: 'git@github.com:70-6C-65-61-73-75-72-65h/jenkins-shared-library-1.git', credentialsId: 'jenkins-shared-library-1']
// // )

// pipeline {
//   agent {
//     label 'buildkit'
//   }
//   // tools{
//   //   maven 'maven-3.9'
//   // }
//   stages{
//     // stage("CHECK"){
//     //   steps{
//     //     echo "is primary branch? - ${env.BRANCH_IS_PRIMARY}"
//     //     echo "BRANCH_NAME: ${env.BRANCH_NAME}"
//     //     echo "GIT_BRANCH: ${env.GIT_BRANCH}"
//     //     echo "BUILD_NUMBER: ${env.BUILD_NUMBER}"
//     //     echo "BUILD_ID: ${env.BUILD_ID}"
//     //     echo "BUILD_TAG: ${env.BUILD_TAG}"
//     //     echo "EXECUTOR_NUMBER: ${env.EXECUTOR_NUMBER}"
//     //     echo "NODE_NAME: ${env.NODE_NAME}"
//     //     echo "GIT_COMMITTER_NAME: ${env.GIT_COMMITTER_NAME}"
//     //     echo "CHANGE_ID: ${env.CHANGE_ID}"
//     //   }
//     // }
//     // stage("TEST"){
//     //   input {
//     //     message "Choose env to deploy it:"
//     //     ok "Done"
//     //     parameters { choice(name: "ENV", choices: ['dev', 'staging', 'prod'], description:"Deployment env") }
//     //   }
//     //   steps {
//     //     script{
//     //       def ENV2 = input message: "2", ok: "Done", parameters: [ choice(name: "ENV", choices: ['dev', 'staging', 'prod'], description:"Deployment env") ]
//     //       echo "deployment env: $ENV"
//     //       echo "deployment env: $ENV2"
//     //     }
//     //   }
//     // }
//     stage("Build Jar file"){
//       steps{
//         script{
//           buildJar()
//           archiveArtifacts artifacts: './target/java-maven-app-*.jar', allowEmptyArchive: true
          
//         }
//       }
//     }
//     // stage("Build Image"){
//     //   steps{
//     //     script{
//     //       buildImage("myprojectsthebest/devops-bootcamp-demo:jmaic-1.1")
//     //     }
//     //   }
//     // }
//     stage("Deploy"){
//       steps{
//         echo "deploy the app..."
//       }
//     }
//   }
// }
