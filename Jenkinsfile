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


node('ibm-jenkins-slave-nvm') {
  def lib = library("jenkins-library@features/parse-artifact").org.zowe.jenkins_shared_library

  def pipeline = lib.pipelines.generic.GenericPipeline.new(this)
  def manifest

  pipeline.admins.add("jackjia")

  pipeline.setup(
    packageName: 'org.zowe',
    github: [
      email                      : lib.Constants.DEFAULT_GITHUB_ROBOT_EMAIL,
      usernamePasswordCredential : lib.Constants.DEFAULT_GITHUB_ROBOT_CREDENTIAL,
    ],
    artifactory: [
      url                        : lib.Constants.DEFAULT_ARTIFACTORY_URL,
      usernamePasswordCredential : lib.Constants.DEFAULT_ARTIFACTORY_ROBOT_CREDENTIAL,
    ],
    pax: [
      sshHost                    : lib.Constants.DEFAULT_PAX_PACKAGING_SSH_HOST,
      sshPort                    : lib.Constants.DEFAULT_PAX_PACKAGING_SSH_PORT,
      sshCredential              : lib.Constants.DEFAULT_PAX_PACKAGING_SSH_CREDENTIAL,
      remoteWorkspace            : lib.Constants.DEFAULT_PAX_PACKAGING_REMOTE_WORKSPACE,
    ],
    extraInit: {
      def commitHash = sh(script: 'git rev-parse --verify HEAD', returnStdout: true).trim()

      sh """
sed -e 's#{BUILD_BRANCH}#${env.BRANCH_NAME}#g' \
    -e 's#{BUILD_NUMBER}#${env.BUILD_NUMBER}#g' \
    -e 's#{BUILD_COMMIT_HASH}#${commitHash}#g' \
    -e 's#{BUILD_TIMESTAMP}#${currentBuild.startTimeInMillis}#g' \
    manifest.json.template > manifest.json
"""
      echo "Current manifest.json is:"
      sh "cat manifest.json"
      manifest = readJSON(file: 'manifest.json')
      if (!manifest || !manifest['name'] || manifest['name'] != 'Zowe' || !manifest['version']) {
        error "Cannot read manifest or manifest is invalid."
      }

      pipeline.setVersion(manifest['version'])
    }
  )

  pipeline.build(
    timeout       : [time: 5, unit: 'MINUTES'],
    isSkippable   : false,
    operation     : {
      // replace templates
      def zoweVersion = pipeline.getVersion()
      echo 'replacing templates...'
      // sh "sed -e 's/{ZOWE_VERSION}/${zoweVersion}/g' artifactory-download-spec.json.template > artifactory-download-spec.json && rm artifactory-download-spec.json.template"
      // sh "sed -e 's/{ZOWE_VERSION}/${zoweVersion}/g' install/zowe-install.yaml.template > install/zowe-install.yaml && rm install/zowe-install.yaml.template"

      def spec = pipeline.artifactory.interpretArtifactDefinitions(manifest['binaryDependencies'], [ "target": ".pax/content/zowe-{ZOWE_VERSION}/files/"])
      echo "$spec"

      error 'stop here...'

      // download components
      pipeline.artifactory.download(
        spec        : 'artifactory-download-spec.json',
        expected    : 18
      )
    }
  )

  // FIXME: we may move smoke test into this pipeline
  pipeline.test(
    name              : "Smoke",
    operation         : {
        echo 'Skip until test case are embeded into this pipeline.'
    },
    allowMissingJunit : true
  )

  // how we packaging jars/zips
  pipeline.packaging(name: 'zowe')

  // define we need publish stage
  pipeline.publish(
    artifacts: [
      '.pax/zowe.pax'
    ]
  )

  pipeline.end()
}
