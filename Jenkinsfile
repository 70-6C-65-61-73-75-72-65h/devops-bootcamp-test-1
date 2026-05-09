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
  }
}