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
  def lib = library("jenkins-library").org.zowe.jenkins_shared_library

  def pipeline = lib.pipelines.generic.GenericPipeline.new(this)
  def manifest

  pipeline.admins.add("jackjia", "stevenh", "joewinchester", "markackert")

  // we have extra parameters for integration test
  pipeline.addBuildParameters(
    booleanParam(
      name: 'BUILD_SMPE',
      description: 'If we want to build SMP/e package.',
      defaultValue: false
    ),
    booleanParam(
      name: 'BUILD_DOCKER',
      description: 'If we want to build docker image.',
      defaultValue: false
    ),
    booleanParam(
      name: 'KEEP_TEMP_FOLDER',
      description: 'If leave the temporary packaging folder on remote server.',
      defaultValue: false
    )
  )

  pipeline.setup(
    packageName: 'org.zowe',
    github: [
      email                      : lib.Constants.DEFAULT_GITHUB_ROBOT_EMAIL,
      usernamePasswordCredential : lib.Constants.DEFAULT_GITHUB_ROBOT_CREDENTIAL,
    ],
    artifactory: [
      url                        : lib.Constants.DEFAULT_LFJ_ARTIFACTORY_URL,
      usernamePasswordCredential : lib.Constants.DEFAULT_LFJ_ARTIFACTORY_ROBOT_CREDENTIAL,
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
      // prepareing download spec
      echo 'prepareing download spec ...'
      def spec = pipeline.artifactory.interpretArtifactDefinitions(manifest['binaryDependencies'], [ "target": ".pax/content/zowe-${manifest['version']}/files/" as String])
      writeJSON file: 'artifactory-download-spec.json', json: spec, pretty: 2
      echo "================ download spec ================"
      sh "cat artifactory-download-spec.json"

      // download components
      pipeline.artifactory.download(
        spec        : 'artifactory-download-spec.json',
        expected    : 19
      )

      // we want build log pulled in for SMP/e build
      if (params.BUILD_SMPE) {
        def buildLogSpec = readJSON(text: '{"files":[]}')
        buildLogSpec['files'].push([
          "target": ".pax/content/smpe/",
          "flat": "true",
          "pattern": pipeline.getPublishTargetPath() + "smpe-build-logs-*.pax.Z",
          "sortBy": ["created"],
          "sortOrder": "desc",
          "limit": 1
        ])
        writeJSON file: 'smpe-build-log-download-spec.json', json: buildLogSpec, pretty: 2
        echo "================ SMP/e build log download spec ================"
        sh "cat smpe-build-log-download-spec.json"

        pipeline.artifactory.download(
          spec        : 'smpe-build-log-download-spec.json'
        )
      }
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

  pipeline.packaging(
    name          : "zowe",
    timeout       : [time: 90, unit: 'MINUTES'],
    operation: {
      pipeline.pax.pack(
          job                 : "zowe-packaging",
          filename            : 'zowe.pax',
          environments        : [
            'ZOWE_VERSION'    : pipeline.getVersion(),
            'BUILD_SMPE'      : (params.BUILD_SMPE ? 'yes' : ''),
            'KEEP_TEMP_FOLDER': (params.KEEP_TEMP_FOLDER ? 'yes' : '')
          ],
          extraFiles          : (params.BUILD_SMPE ? 'zowe-smpe.zip,fmid.zip,pd.htm,smpe-promote.tar,smpe-build-logs.pax.Z,rename-back.sh' : ''),
          keepTempFolder      : params.KEEP_TEMP_FOLDER
      )
      if (params.BUILD_SMPE) {
        // rename SMP/e build with correct FMID name
        sh "cd .pax && chmod +x rename-back.sh && cat rename-back.sh && ./rename-back.sh"
      }
    }
  )

  // define we need publish stage
  pipeline.publish(
    artifacts: [
      '.pax/zowe.pax',
      '.pax/zowe-smpe.zip',
      '.pax/smpe-promote.tar',
      '.pax/pd.htm',
      '.pax/smpe-build-logs.pax.Z',
      '.pax/AZWE*'
    ]
  )

  // 
  pipeline.createStage(
    name: "Build Docker",
    timeout: [ time: 120, unit: 'MINUTES' ],
    isSkippable: true,
    showExecute: {
      return params.BUILD_DOCKER
    },
    stage : {
      sh 'echo ">>>>>>>>>>>>>>>>>> parent-node: " && pwd && ls -la'
      // this is a hack to find the zowe.pax upload
      // FIXME: ideally this should be reachable from pipeline property
      def zowePaxUploaded = sh(
          script: "cat .tmp-pipeline-publish-spec.json | jq -r '.files[] | select(.pattern == \".pax/zowe.pax\") | .target",
          returnStdout: true
        ).trim()
      echo "zowePaxUploaded=${zowePaxUploaded}"
      if (zowePaxUploaded == "") {
        sh "echo 'content of .tmp-pipeline-publish-spec.json' && cat .tmp-pipeline-publish-spec.json"
        error "Couldn't find zowe.pax uploaded."
      }
      node('ibm-jenkins-slave-dind') {
        // checkout source code to docker build agent
        checkout scm
        // checkout repository with dockerfile
        // FIXME: this dockerfile should be merged into current repo to avoid
        //        version synchronizing issues
        sh 'git clone --branch s390x https://github.com/1000TurquoisePogs/zowe-dockerfiles.git'
        dir ('zowe-dockerfiles/dockerfiles/zowe-release/amd64/zowe-v1-lts') {
          // copy utils to docker build folder
          sh 'mkdir -p utils && cp ../../../../utils/* ./utils'
          // download zowe pax to docker build agent
          pipeline.artifactory.download(spec: zowePaxUploaded, expected: 1)
          sh 'mv zowe*.pax zowe.pax'
          // show files
          sh 'echo ">>>>>>>>>>>>>>>>>> sub-node: " && pwd && ls -ltr .'

          withCredentials([usernamePassword(
            credentialsId: 'DockerGizaUser',
            usernameVariable: 'dockeruser',
            passwordVariable: 'unused'
          )]){
            // build docker image
            sh "docker build -f Dockerfile.jenkins -t ${dockeruser}/zowe-v1-lts:amd64 ."
          }
        }
      }
    }
  )


  pipeline.end()
}
