pipeline {
  agent any
  stages{
    stage("CHECK"){
      steps{
        echo "is primary branch? - $BRANCH_IS_PRIMARY"
        echo "BRANCH_NAME: $BRANCH_NAME"
        echo "BUILD_NUMBER: $BUILD_NUMBER"
        echo "BUILD_ID: $BUILD_ID"
        echo "BUILD_TAG: $BUILD_TAG"
        echo "EXECUTOR_NUMBER: $EXECUTOR_NUMBER"
        echo "NODE_NAME: $NODE_NAME"
        echo "GIT_COMMITTER_NAME: $GIT_COMMITTER_NAME"
        echo "CHANGE_ID: $CHANGE_ID"
      }
    }
  }
}