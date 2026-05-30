@Library('jenkins-shared-library-1')_

pipeline {
  agent {
    label: 'buildkit'
  }
  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '10'))
    timeout(time: 45, unit: 'MINUTES')
  }
  environment {
    BUILDKIT_HOST = 'tcp://buildkit:1234'
    // REGISTRY = 'nexus:8083'
    // IMAGE_REPO = 'nexus:8083/devops-bootcamp-demo:jmaic-1.0'
    // IMAGE_REPO = 'nexus:8083/devops-bootcamp-demo'
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
          // env.IMAGE = "${IMAGE_REPO}:${env.IMAGE_TAG}"
          echo "IMAGE_TAG: ${env.IMAGE_TAG}"
        }
      }
    }
    stage("Tool Sanity Check"){
      steps{
        sh """
          set -eux
          java -version
          maven -version
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

    stage('Maven dependency scan') {
      steps {
        sh """
          set -eux

          # OSV scan по source/dependency manifests
          osv-scanner scan source \
            --recursive \
            --format=json \
            --output=\"$REPORT_DIR/osv-source.json\" \
            .

          # Grype scan по Maven CycloneDX SBOM
          grype sbom:\"$REPORT_DIR/maven-sbom.cdx.json\" \
            -o json > \"$REPORT_DIR/grype-maven-sbom.json\"

          # Gate: HIGH/CRITICAL ломают билд
          grype sbom:\"$REPORT_DIR/maven-sbom.cdx.json\" \
            --fail-on high
        """
      }
    }

    stage('OWASP Dependency-Check') {
      steps {
        sh """
          set -eux

          mvn -B -ntp org.owasp:dependency-check-maven:check \
            -Dformat=ALL \
            -DfailBuildOnCVSS=9 \
            -DoutputDirectory=\"$REPORT_DIR/dependency-check\"
        """
      }
    }


  }
  post {
    always {
      archiveArtifacts artifacts: "$REPORT_DIR/**/*" allowEmptyArchive: true
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
