pipeline {
  agent any
  stages{
    stage("CHECK"){
      steps{
        echo "is primary branch? - ${env.BRANCH_IS_PRIMARY}"
        echo "BRANCH_NAME: ${env.BRANCH_NAME}"
        echo "BUILD_NUMBER: ${env.BUILD_NUMBER}"
        echo "BUILD_ID: ${env.BUILD_ID}"
        echo "BUILD_TAG: ${env.BUILD_TAG}"
        echo "EXECUTOR_NUMBER: ${env.EXECUTOR_NUMBER}"
        echo "NODE_NAME: ${env.NODE_NAME}"
        echo "GIT_COMMITTER_NAME: ${env.GIT_COMMITTER_NAME}"
        echo "CHANGE_ID: ${env.CHANGE_ID}"
      }
    }
    stage("TEST"){
      input {
        message: "Choose env to deploy it:"
        ok: "Done"
        parameters: { choice(name: "ENV", choices: ['dev', 'staging', 'prod'], description:"Deployment env") }
      }
      steps {
        script{
          def ENV2 = input message: "2", ok: "Done", parameters: [ choice(name: "ENV", choices: ['dev', 'staging', 'prod'], description:"Deployment env") ]
          echo "deployment env: $ENV"
          echo "deployment env: $ENV2"
        }
      }
    }
  }
}
