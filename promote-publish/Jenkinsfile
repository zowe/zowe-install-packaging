#!groovy

/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018, 2019
 */

def isPullRequest = env.BRANCH_NAME.startsWith('PR-')
def slackChannel = '#test-build-notify'
def zoweInstallPackagingRepo = 'zowe/zowe-install-packaging'

def opts = []
// keep last 20 builds for regular branches, no keep for pull requests
opts.push(buildDiscarder(logRotator(numToKeepStr: (isPullRequest ? '' : '20'))))
// disable concurrent build
opts.push(disableConcurrentBuilds())

// define custom build parameters
def customParameters = []
// >>>>>>>> parameters to control pipeline behavior
// >>>>>>>> parameters of artifactory
customParameters.push(string(
  name: 'ARTIFACTORY_URL',
  description: 'Artifactory URL',
  defaultValue: 'https://gizaartifactory.jfrog.io/gizaartifactory',
  trim: true,
  required: true
))
customParameters.push(credentials(
  name: 'ARTIFACTORY_SECRET',
  description: 'Artifactory access secret',
  credentialType: 'com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl',
  defaultValue: 'GizaArtifactory',
  required: true
))
customParameters.push(string(
  name: 'ZOWE_BUILD_REPOSITORY',
  description: 'Zowe successful build repository',
  defaultValue: 'libs-snapshot-local',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'ZOWE_BUILD_NAME',
  description: 'Zowe successful build name',
  defaultValue: 'zowe-install-packaging :: master',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'ZOWE_BUILD_NUMBER',
  description: 'REQUIRED if ZOWE_BUILD_RC_PATH is empty. Zowe successful build number',
  defaultValue: '',
  trim: true
))
customParameters.push(string(
  name: 'ZOWE_BUILD_RC_PATH',
  description: 'REQUIRED if ZOWE_BUILD_NUMBER is empty. Zowe RC build artifactory download path. If the build original file has been removed from artifactory, we can promote any existing file. Example: libs-release-local/org/zowe/0.9.3-RC2/zowe-0.9.3-RC2.pax',
  defaultValue: '',
  trim: true
))
customParameters.push(string(
  name: 'ZOWE_CLI_BUILD_REPOSITORY',
  description: 'Zowe CLI successful build repository',
  defaultValue: 'libs-snapshot-local',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'ZOWE_CLI_BUILD_NAME',
  description: 'Zowe CLI successful build name',
  defaultValue: 'Zowe CLI Bundle :: master',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'ZOWE_CLI_BUILD_NUMBER',
  description: 'REQUIRED if ZOWE_CLI_BUILD_RC_PATH is empty. Zowe CLI successful build number',
  defaultValue: '',
  trim: true
))
customParameters.push(string(
  name: 'ZOWE_CLI_BUILD_RC_PATH',
  description: 'REQUIRED if ZOWE_CLI_BUILD_NUMBER is empty. Zowe CLI build artifactory download path. If the build original file has been removed from artifactory, we can promote any existing file. Example: libs-release-local/org/zowe/0.9.3-RC2/zowe-cli-package-0.9.3.zip',
  defaultValue: '',
  trim: true
))
customParameters.push(string(
  name: 'ZOWE_RELEASE_REPOSITORY',
  description: 'Zowe release repository',
  defaultValue: 'libs-release-local',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'ZOWE_RELEASE_PATH',
  description: 'Zowe release path',
  defaultValue: '/org/zowe',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'ZOWE_RELEASE_CATEGORY',
  description: 'REQUIRED. Zowe release category. For example, stable',
  defaultValue: 'stable',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'ZOWE_RELEASE_VERSION',
  description: 'REQUIRED. Zowe release version without prefix v. For example, 0.9.0',
  defaultValue: '',
  trim: true,
  required: true
))
// >>>>>>>> SSH access of testing server zOSaaS layer
customParameters.push(string(
  name: 'PUBLISH_SSH_HOST',
  description: 'Host of publishing server',
  defaultValue: 'wash.zowe.org',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'PUBLISH_SSH_PORT',
  description: 'SSH port of publishing server',
  defaultValue: '22',
  trim: true,
  required: true
))
customParameters.push(credentials(
  name: 'PUBLISH_SSH_CREDENTIAL',
  description: 'The SSH credential used to connect publishing server',
  credentialType: 'com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl',
  defaultValue: 'ssh-zowe-publish',
  required: true
))
customParameters.push(string(
  name: 'PUBLISH_DIRECTORY',
  description: 'Publishing directory',
  defaultValue: '/var/www/projectgiza.org/builds',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'CODE_SIGNING_KEY_PASSPHRASE',
  description: 'Key ID and passphrase to sign the build',
  credentialType: 'com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl',
  defaultValue: 'code-signing-key-passphrase-jack',
  required: false
))
customParameters.push(credentials(
  name: 'GITHUB_CREDENTIALS',
  description: 'Github user credentials',
  credentialType: 'com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl',
  defaultValue: 'zowe-robot-github',
  required: true
))
customParameters.push(string(
  name: 'GITHUB_USER_EMAIL',
  description: 'github user email',
  defaultValue: 'zowe.robot@gmail.com',
  trim: true,
  required: true
))
customParameters.push(string(
  name: 'GITHUB_USER_NAME',
  description: 'github user name',
  defaultValue: 'Zowe Robot',
  trim: true,
  required: true
))

opts.push(parameters(customParameters))

// set build properties
properties(opts)

node ('ibm-jenkins-slave-nvm-jnlp') {
  currentBuild.result = 'SUCCESS'

  def releaseFilename = "zowe-${params.ZOWE_RELEASE_VERSION}.pax"
  def releaseCliFilename = "zowe-cli-package-${params.ZOWE_RELEASE_VERSION}.zip"
  def releaseFilePath = "${params.ZOWE_RELEASE_REPOSITORY}${params.ZOWE_RELEASE_PATH}/${params.ZOWE_RELEASE_VERSION}"
  def releaseFileFull = "${releaseFilePath}/${releaseFilename}"
  def releaseCliFileFull = "${releaseFilePath}/${releaseCliFilename}"
  def isFormalRelease = false
  def gitRevision = null
  def gitCliRevision = null

  try {

    stage('validate') {
      if (!params.ZOWE_RELEASE_REPOSITORY) {
        error "ZOWE_RELEASE_REPOSITORY is required to promote build."
      }
      if (!params.ZOWE_BUILD_NAME) {
        error "ZOWE_BUILD_NAME is required to promote build."
      }
      if (!params.ZOWE_BUILD_NUMBER && !params.ZOWE_BUILD_RC_PATH) {
        error "ZOWE_BUILD_NUMBER or ZOWE_BUILD_RC_PATH is required to promote build."
      }
      if (!params.ZOWE_CLI_BUILD_NAME) {
        error "ZOWE_CLI_BUILD_NAME is required to promote build."
      }
      if (!params.ZOWE_CLI_BUILD_NUMBER && !params.ZOWE_CLI_BUILD_RC_PATH) {
        error "ZOWE_CLI_BUILD_NUMBER or ZOWE_CLI_BUILD_RC_PATH is required to promote build."
      }
      if (!params.ZOWE_RELEASE_CATEGORY) {
        error "ZOWE_RELEASE_CATEGORY is required to promote build."
      }
      if (!params.ZOWE_RELEASE_VERSION) {
        error "ZOWE_RELEASE_VERSION is required to promote build."
      }

      // thanks semver/semver, this regular expression comes from
      // https://github.com/semver/semver/issues/232#issuecomment-405596809
      if (!(params.ZOWE_RELEASE_VERSION ==~ /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$/)) {
        error "${params.ZOWE_RELEASE_VERSION} is not a valid semantic version."
      }
      if (params.ZOWE_RELEASE_VERSION ==~ /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/) {
        isFormalRelease = true
        echo ">>>> Version ${params.ZOWE_RELEASE_VERSION} is considered as a FORMAL RELEASE."
      } else {
        echo ">>>> Version ${params.ZOWE_RELEASE_VERSION} is NOT considered as a FORMAL RELEASE."
      }

      echo "Checking if ${params.ZOWE_RELEASE_VERSION} already exists ..."

      // prepare JFrog CLI configurations
      withCredentials([usernamePassword(credentialsId: params.ARTIFACTORY_SECRET, passwordVariable: 'PASSWORD', usernameVariable: 'USERNAME')]) {
        sh "jfrog rt config rt-server-1 --url=${params.ARTIFACTORY_URL} --user=${USERNAME} --password=${PASSWORD}"
      }

      // check artifactory
      def versionOnArtifactory = sh(
        script: "jfrog rt s \"${releaseFilePath}/\"",
        returnStdout: true
      ).trim()
      echo "Search result: ${versionOnArtifactory}"
      if (versionOnArtifactory != '[]') {
        error "Zowe version ${params.ZOWE_RELEASE_VERSION} already exists (${releaseFilePath})"
      } else {
        echo ">>>> Target artifactory folder doesn't exist, may proceed."
      }

      // check build info
      if (params.ZOWE_BUILD_NUMBER) {
        gitRevision = getArtifactoryBuildInfoByAPI(
          params.ARTIFACTORY_URL,
          params.ARTIFACTORY_SECRET,
          params.ZOWE_BUILD_NAME,
          params.ZOWE_BUILD_NUMBER,
          '.buildInfo.vcsRevision'
        )
        if (!(gitRevision ==~ /^[0-9a-fA-F]{40}$/)) { // if it's a SHA-1 commit hash
          error "Cannot extract git revision from build \"${params.ZOWE_BUILD_NAME}/${params.ZOWE_BUILD_NUMBER}\""
        }
        echo ">>>> Build ${params.ZOWE_BUILD_NAME}/${params.ZOWE_BUILD_NUMBER} commit hash is ${gitRevision}, may proceed."
      }
      if (params.ZOWE_CLI_BUILD_NUMBER) {
        gitCliRevision = getArtifactoryBuildInfoByAPI(
          params.ARTIFACTORY_URL,
          params.ARTIFACTORY_SECRET,
          params.ZOWE_CLI_BUILD_NAME,
          params.ZOWE_CLI_BUILD_NUMBER,
          '.buildInfo.vcsRevision'
        )
        if (!(gitCliRevision ==~ /^[0-9a-fA-F]{40}$/)) { // if it's a SHA-1 commit hash
          error "Cannot extract git revision from build \"${params.ZOWE_CLI_BUILD_NAME}/${params.ZOWE_CLI_BUILD_NUMBER}\""
        }
        echo ">>>> Build ${params.ZOWE_CLI_BUILD_NAME}/${params.ZOWE_CLI_BUILD_NUMBER} commit hash is ${gitCliRevision}, may proceed."
      }

      // check deploy target directory
      withCredentials([usernamePassword(credentialsId: params.PUBLISH_SSH_CREDENTIAL, passwordVariable: 'PASSWORD', usernameVariable: 'USERNAME')]) {
        // move to target folder, split and generate hash
        def versionOnPublishDir = sh(script:"""SSHPASS=${PASSWORD} sshpass -e ssh -tt -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -p ${params.PUBLISH_SSH_PORT} ${USERNAME}@${params.PUBLISH_SSH_HOST} << EOF
[ -d '${params.PUBLISH_DIRECTORY}/${params.ZOWE_RELEASE_CATEGORY}/${params.ZOWE_RELEASE_VERSION}' ] && exit 1
exit 0
EOF""", returnStatus:true)
        echo "Exit code: ${versionOnPublishDir}"
        if ("${versionOnPublishDir}" == "1") {
          error "Zowe version ${params.ZOWE_RELEASE_VERSION} already exists (${params.PUBLISH_DIRECTORY}/${params.ZOWE_RELEASE_CATEGORY}/${params.ZOWE_RELEASE_VERSION})"
        } else {
          echo ">>>> Target publish folder doesn't exist, may proceed."
        }
      }
    }

    stage('checkout') {
      // checkout source code
      checkout scm

      // check if it's pull request
      echo "Current branch is ${env.BRANCH_NAME}"
      if (isPullRequest) {
        echo "This is a pull request"
      }
    }

    stage('promote') {
      // get build information
      def buildInfo = getArtifactInfoByCLI(
        (params.ZOWE_BUILD_RC_PATH) ? params.ZOWE_BUILD_RC_PATH : "${params.ZOWE_BUILD_REPOSITORY}/*",
        (params.ZOWE_BUILD_RC_PATH) ? '': params.ZOWE_BUILD_NAME,
        (params.ZOWE_BUILD_RC_PATH) ? '': params.ZOWE_BUILD_NUMBER
      )

      // get original build name/number
      if (buildInfo['build.name'].contains('zowe-promote-publish') &&
        buildInfo['build.parentName'] && buildInfo['build.parentNumber']) {
        buildInfo['build.name'] = buildInfo['build.parentName']
        buildInfo['build.number'] = buildInfo['build.parentNumber']
      }

      // retrieve gitRevision if doesn't exist, which doesn't provide ZOWE_BUILD_NUMBER
      if (!gitRevision) {
        gitRevision = getArtifactoryBuildInfoByAPI(
          params.ARTIFACTORY_URL,
          params.ARTIFACTORY_SECRET,
          buildInfo['build.name'],
          buildInfo['build.number'],
          '.buildInfo.vcsRevision'
        )
        if (!(gitRevision ==~ /^[0-9a-fA-F]{40}$/)) { // if it's a SHA-1 commit hash
          error "Cannot extract git revision from build \"${buildInfo['build.name']}/${buildInfo['build.number']}\""
        }
      }

      // promote Zowe build artifact
      promoteArtifact(buildInfo, releaseFilePath, releaseFilename)

      // get CLI build information
      def cliBuildInfo = getArtifactInfoByCLI(
        (params.ZOWE_CLI_BUILD_RC_PATH) ? params.ZOWE_CLI_BUILD_RC_PATH : "${params.ZOWE_CLI_BUILD_REPOSITORY}/*",
        (params.ZOWE_CLI_BUILD_RC_PATH) ? '' : params.ZOWE_CLI_BUILD_NAME,
        (params.ZOWE_CLI_BUILD_RC_PATH) ? '' : params.ZOWE_CLI_BUILD_NUMBER
      )

      // get original CLI build name/number
      if (cliBuildInfo['build.name'].contains('zowe-promote-publish') &&
        cliBuildInfo['build.parentName'] && cliBuildInfo['build.parentNumber']) {
        cliBuildInfo['build.name'] = cliBuildInfo['build.parentName']
        cliBuildInfo['build.number'] = cliBuildInfo['build.parentNumber']
      }

      // promote CLI build artifact
      promoteArtifact(cliBuildInfo, releaseFilePath, releaseCliFilename)
    }

    utils.conditionalStage('tag', isFormalRelease) {
      // tag the repositories for a formal release
      tagGithubRepository(
        zoweInstallPackagingRepo,
        gitRevision,
        "v${params.ZOWE_RELEASE_VERSION}",
        params.GITHUB_CREDENTIALS,
        params.GITHUB_USER_NAME,
        params.GITHUB_USER_EMAIL
      )
    }

    stage('publish') {
      // download build
      sh "jfrog rt download --flat \"${releaseFileFull}\""
      sh "jfrog rt download --flat \"${releaseCliFileFull}\""

      withCredentials([usernamePassword(credentialsId: params.PUBLISH_SSH_CREDENTIAL, passwordVariable: 'PASSWORD', usernameVariable: 'USERNAME')]) {
        withCredentials([usernamePassword(credentialsId: params.CODE_SIGNING_KEY_PASSPHRASE, passwordVariable: 'CODE_SIGNING_PASSPHRASE', usernameVariable: 'CODE_SIGNING_KEY')]) {
          // upload to publish server
          sh """SSHPASS=${PASSWORD} sshpass -e sftp -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P ${params.PUBLISH_SSH_PORT} ${USERNAME}@${params.PUBLISH_SSH_HOST} << EOF
put ${releaseFilename}
put ${releaseCliFilename}
put scripts/zowe-publish.sh
bye
EOF"""

          // move to target folder, split and generate hash
          sh """SSHPASS=${PASSWORD} sshpass -e ssh -tt -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -p ${params.PUBLISH_SSH_PORT} ${USERNAME}@${params.PUBLISH_SSH_HOST} << EOF
cd ~ && chmod +x zowe-publish.sh && ./zowe-publish.sh "${params.PUBLISH_DIRECTORY}" "${params.ZOWE_RELEASE_CATEGORY}" "${params.ZOWE_RELEASE_VERSION}" "${CODE_SIGNING_KEY}" "${CODE_SIGNING_PASSPHRASE}" || exit 1
exit 0
EOF"""
        }
      }

    }

    stage('done') {
      def source = ""
      if (params.ZOWE_BUILD_NUMBER) {
        source = "Build #${params.ZOWE_BUILD_NUMBER}"
      } else if (params.ZOWE_BUILD_RC_PATH) {
        source = "File \"${params.ZOWE_BUILD_RC_PATH}\""
      }
      def successMsg = """
*************************************************************************************************

${source} is promoted as Zowe v${params.ZOWE_RELEASE_VERSION}, you can download from:

${params.ARTIFACTORY_URL}/${releaseFileFull}
or:
https://projectgiza.org/builds/${params.ZOWE_RELEASE_CATEGORY}/${params.ZOWE_RELEASE_VERSION}/${releaseFilename}

The CLI Standalone Package is published here:
${params.ARTIFACTORY_URL}/${releaseCliFileFull}
or:
https://projectgiza.org/builds/${params.ZOWE_RELEASE_CATEGORY}/${params.ZOWE_RELEASE_VERSION}/${releaseCliFilename}

*************************************************************************************************
      """
      echo successMsg

      emailext body: "Job \"${env.JOB_NAME}\" build #${env.BUILD_NUMBER} succeeded.\n\nCheck detail: ${env.BUILD_URL}" ,
          subject: "[Jenkins] Job \"${env.JOB_NAME}\" build #${env.BUILD_NUMBER} succeeded\n\n${successMsg}",
          recipientProviders: [
            [$class: 'RequesterRecipientProvider'],
            [$class: 'CulpritsRecipientProvider'],
            [$class: 'DevelopersRecipientProvider'],
            [$class: 'UpstreamComitterRecipientProvider']
          ]
    }

  } catch (err) {
    currentBuild.result = 'FAILURE'

    emailext body: "Job \"${env.JOB_NAME}\" build #${env.BUILD_NUMBER} failed.\n\nError: ${err}\n\nCheck detail: ${env.BUILD_URL}" ,
        subject: "[Jenkins] Job \"${env.JOB_NAME}\" build #${env.BUILD_NUMBER} failed",
        recipientProviders: [
          [$class: 'RequesterRecipientProvider'],
          [$class: 'CulpritsRecipientProvider'],
          [$class: 'DevelopersRecipientProvider'],
          [$class: 'UpstreamComitterRecipientProvider']
        ]

    throw err
  }
}
