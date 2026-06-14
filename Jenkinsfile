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
    // boolean(name:"IS_AWS_ECR_REPO", defaultValue: false, description: "Specify is it aws ecr repo to push to or other regular one")
    // string(name: "AWS_REGION", defaultValue: "eu-north-1", description:"AWS_REGION")
    choice(
            name: 'AWS_REGION', 
            choices: [null, 'us-east-1', 'eu-north-1'],  //default for non aws // default for aws public ecr (Virginia) // aws private ecr
            description: 'Select which aws region is used if its aws ecr repo to push the image'
        )
    // choice(
    //         name: 'MAVEN_PACKAGE_VERSION_LEVEL_TO_UPDATE', 
    //         choices: ['Incremental', 'Minor', 'Major'], 
    //         description: 'Select which version level should be updated for maven app.'
    //     )
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
          env.AWS_REGION = "${params.AWS_REGION}"

          echo "GIT_URL: ${env.GIT_URL}"
          echo "${env.GIT_URL}"
          echo "https://github.com/70-6C-65-61-73-75-72-65h/devops-bootcamp-test-1.git"


          if(env.GIT_URL == "https://github.com/70-6C-65-61-73-75-72-65h/devops-bootcamp-test-1.git"){
            env.AWS_REGION = 'eu-north-1'
            env.REGISTRY = 'public.ecr.aws'
            env.IMAGE_REPO = 't9g8l3y5/checking-devops'
            env.REPO_CREDS_ID = 'jenkins-ecr-pusher-creds'
          }
          if(env.AWS_REGION != 'eu-north-1'){
            error "Stopping pipeline: Condition was met!" 
          }
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
          aws --version
        '''
      }
    }

    stage("Dockerfile Lint"){
      steps { 
        dockerfileLint()
      }
    }

    // stage("Update maven app version"){
    //   steps {
    //     script {
    //       if(params.MAVEN_PACKAGE_VERSION_LEVEL_TO_UPDATE == 'Major'){
    //         sh '''mvn build-helper:parse-version versions:set \
    //      '-DnewVersion=${parsedVersion.nextMajorVersion}.${parsedVersion.minorVersion}.${parsedVersion.incrementalVersion}' versions:commit'''
    //       } else if(params.MAVEN_PACKAGE_VERSION_LEVEL_TO_UPDATE == 'Minor'){
    //         sh '''mvn build-helper:parse-version versions:set \
    //      '-DnewVersion=${parsedVersion.majorVersion}.${parsedVersion.nextMinorVersion}.${parsedVersion.incrementalVersion}' versions:commit'''
    //       } else {
    //         sh '''mvn build-helper:parse-version versions:set \
    //      '-DnewVersion=${parsedVersion.majorVersion}.${parsedVersion.minorVersion}.${parsedVersion.nextIncrementalVersion}' versions:commit'''
    //       }
    //     }
         
    //   }
    // }

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
        script{
          if(env.AWS_REGION){
            withCredentials([[ $class: 'AmazonWebServicesCredentialsBinding', credentialsId: "$REPO_CREDS_ID" ]]){ //jenkins-ecr-pusher-creds
              sh '''
              set -euox pipefail

              export DOCKER_CONFIG="$(mktemp -d)"

              cleanup(){
                rc=$?
                rm -rf "$DOCKER_CONFIG"
                exit "$rc"
              }

              trap cleanup EXIT INT TERM HUP


              echo "$(aws sts get-caller-identity)"

              set +x

              echo "$(aws sts get-caller-identity)"

              if [ "$REGISTRY" = "public.ecr.aws" ]; then
                PASSWORD=$(aws ecr-public get-login-password --region 'us-east-1')
              else
                PASSWORD=$(aws ecr get-login-password --region "$AWS_REGION")
              fi

              AUTH=$(printf 'AWS:%s' $PASSWORD | base64 | tr -d '\\n')

              jq -n \
                --arg auth "$AUTH" \
                --arg registry "$REGISTRY_DOCKER_CONFIG" \
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
          } else {
            buildAndPushImage(env.REPO_CREDS_ID)
          }
        }
        }
    }

    stage("Image SBOM - SYFT"){ 
      steps {
        script {
          catchError {
          if(!env.AWS_REGION){
            withCredentials([usernamePassword(
              credentialsId: "$REPO_CREDS_ID",
              usernameVariable: "USER",
              passwordVariable: "PASSWORD")]){
                  sh '''
                    set -eux;
                    export SYFT_REGISTRY_AUTH_AUTHORITY="$REGISTRY"
                    export SYFT_REGISTRY_AUTH_USERNAME="$USER"
                    export SYFT_REGISTRY_AUTH_PASSWORD="$PASSWORD"

                    syft registry:"$IMAGE_NAME" \
                      -o cyclonedx-json="$REPORT_DIR/image-sbom.cdx.json" \
                      -o spdx-json="$REPORT_DIR/image-sbom.spdx.json" \
                  '''
            }
          } else {
            withCredentials([[ $class: 'AmazonWebServicesCredentialsBinding', credentialsId: "$REPO_CREDS_ID" ]]){  
              sh '''
              echo "$(aws sts get-caller-identity)"

              if [ "$REGISTRY" = "public.ecr.aws" ]; then 
                PASSWORD=$(aws ecr-public get-login-password --region 'us-east-1')
              else
                PASSWORD=$(aws ecr get-login-password --region "$AWS_REGION")
              fi

              set -eux;
              export SYFT_REGISTRY_AUTH_AUTHORITY="$REGISTRY"
              export SYFT_REGISTRY_AUTH_USERNAME="AWS"
              export SYFT_REGISTRY_AUTH_PASSWORD="$PASSWORD"

              syft registry:"$IMAGE_NAME" \
                -o cyclonedx-json="$REPORT_DIR/image-sbom.cdx.json" \
                -o spdx-json="$REPORT_DIR/image-sbom.spdx.json" \
              '''
            }
          }
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
      when {
        expression {
          !env.AWS_REGION // but we actually can implement the same for trivy as for syft above
        }
      }
      steps {
        trivyImageScan(env.REPO_CREDS_ID)
        trivyImageScan(env.REPO_CREDS_ID, 'gate')
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
