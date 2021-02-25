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

node('zowe-jenkins-agent-dind-wdc') {
  def lib = library("jenkins-library@users/tom/autoPRTesting").org.zowe.jenkins_shared_library

  def pipeline = lib.pipelines.generic.GenericPipeline.new(this)
  def manifest
  def zowePaxUploaded

  pipeline.admins.add("jackjia", "tomzhang", "joewinchester", "markackert")

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
        expected    : 25
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
          keepTempFolder      : params.KEEP_TEMP_FOLDER,
          paxOptions          : '-o saveext'
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
  
  pipeline.createStage(
    name: "Build zLinux Docker",
    timeout: [ time: 60, unit: 'MINUTES' ],
    isSkippable: true,
    showExecute: {
      return params.BUILD_DOCKER
    },
    stage : {
      if (params.BUILD_DOCKER) {
        // this is a hack to find the zowe.pax upload
        // FIXME: ideally this should be reachable from pipeline property
        zowePaxUploaded = sh(
          script: "cat .tmp-pipeline-publish-spec.json | jq -r '.files[] | select(.pattern == \".pax/zowe.pax\") | .target'",
          returnStdout: true
        ).trim()
        echo "zowePaxUploaded=${zowePaxUploaded}"
        if (zowePaxUploaded == "") {
          sh "echo 'content of .tmp-pipeline-publish-spec.json' && cat .tmp-pipeline-publish-spec.json"
          error "Couldn't find zowe.pax uploaded."
        }
        
        withCredentials([
          usernamePassword(
            credentialsId: 'ZoweDockerhub',
            usernameVariable: 'USERNAME',
            passwordVariable: 'PASSWORD'
          ),
          sshUserPrivateKey(
            credentialsId: 'zlinux-docker',
            keyFileVariable: 'KEYFILE',
            usernameVariable: 'ZUSER',
            passphraseVariable: 'PASSPHRASE'
          ),
          string(
            credentialsId: 'zlinux-host',
            variable: 'ZHOST'
          )
        ]){
          def Z_SERVER = [
            name         : ZHOST,
            host         : ZHOST,
            port         : 22,
            user         : ZUSER,
            identityFile : KEYFILE,
            passphrase   : PASSPHRASE,
            allowAnyHosts: true
          ]

          sshCommand remote: Z_SERVER, command: \
          """
             mkdir -p zowe-build/${env.BRANCH_NAME}_${env.BUILD_NUMBER}
          """
          sshPut remote: Z_SERVER, from: "containers", into: "zowe-build/${env.BRANCH_NAME}_${env.BUILD_NUMBER}"
          sshCommand remote: Z_SERVER, command: \
          """
             cd zowe-build/${env.BRANCH_NAME}_${env.BUILD_NUMBER}/containers/server-bundle &&
             wget "https://zowe.jfrog.io/zowe/${zowePaxUploaded}" -O zowe.pax &&
             mkdir -p utils && cp -r ../utils/* ./utils &&
             chmod +x ./utils/*.sh ./utils/*/bin/* &&
             sudo docker build --build-arg BUILD_PLATFORM=s390x -t ompzowe/server-bundle:s390x . &&
             sudo docker save -o server-bundle.s390x.tar ompzowe/server-bundle:s390x &&
             sudo chmod 777 * &&
             echo ">>>>>>>>>>>>>>>>>> docker tar: " && pwd && ls -ltr server-bundle.s390x.tar
          """
          sshGet remote: Z_SERVER, from: "zowe-build/${env.BRANCH_NAME}_${env.BUILD_NUMBER}/containers/server-bundle/server-bundle.s390x.tar", into: "server-bundle.s390x.tar"
          pipeline.uploadArtifacts([ 'server-bundle.s390x.tar' ])
          sshCommand remote: Z_SERVER, command: \
          """
             rm -rf zowe-build/${env.BRANCH_NAME}_${env.BUILD_NUMBER}
             sudo docker system prune -f
          """
        }
      }
    }
  )

  pipeline.createStage(
    name: "Build Linux Docker",
    timeout: [ time: 120, unit: 'MINUTES' ],
    isSkippable: true,
    showExecute: {
      return params.BUILD_DOCKER
    },
    stage : {
      if (params.BUILD_DOCKER) {
        // this is a hack to find the zowe.pax upload
        // FIXME: ideally this should be reachable from pipeline property
        if (!zowePaxUploaded) {
          zowePaxUploaded = sh(
            script: "cat .tmp-pipeline-publish-spec.json | jq -r '.files[] | select(.pattern == \".pax/zowe.pax\") | .target'",
            returnStdout: true
          ).trim()
        }
        echo "zowePaxUploaded=${zowePaxUploaded}"
        if (zowePaxUploaded == "") {
          sh "echo 'content of .tmp-pipeline-publish-spec.json' && cat .tmp-pipeline-publish-spec.json"
          error "Couldn't find zowe.pax uploaded."
        }

        dir ('containers/server-bundle') {
          // copy utils to docker build folder
          sh 'mkdir -p utils && cp -r ../utils/* ./utils'
          // download zowe pax to docker build agent
          pipeline.artifactory.download(
            specContent: "{\"files\":[{\"pattern\": \"${zowePaxUploaded}\",\"target\":\"zowe.pax\",\"flat\":\"true\"}]}",
            expected: 1
          )
          // show files
          sh 'echo ">>>>>>>>>>>>>>>>>> sub-node: " && pwd && ls -ltr .'
           withCredentials([usernamePassword(
            credentialsId: 'ZoweDockerhub',
            usernameVariable: 'USERNAME',
            passwordVariable: 'PASSWORD'
          )]){
            // build docker image
            sh "docker build  --build-arg BUILD_PLATFORM=amd64 -t ompzowe/server-bundle:amd64 ."
            sh "docker save -o server-bundle.amd64.tar ompzowe/server-bundle:amd64"
          }
          // show files
          sh 'echo ">>>>>>>>>>>>>>>>>> docker tar: " && pwd && ls -ltr server-bundle.amd64.tar'
          pipeline.uploadArtifacts([ 'server-bundle.amd64.tar' ])
        }      
      }
    }
  )

  pipeline.createStage(
    name              : "Zowe Regular Build",
    timeout: [time: 2, unit: 'HOURS'],
    isSkippable: true,
    shouldExecute : {
      return pipeline.isAuthorizedUser
    },
    stage : {
      def buildName = env.JOB_NAME.replace('/', ' :: ')
      def ZOWE_BUILD_REPOSITORY = 'libs-snapshot-local'
      def ZOWE_CLI_BUILD_REPOSITORY = 'libs-snapshot-local'
      def ZOWE_CLI_BUILD_NAME = 'Zowe CLI Bundle :: master'
      
      sourceRegBuildInfo = pipeline.artifactory.getArtifact([
        'pattern'      : "${ZOWE_BUILD_REPOSITORY}/*/zowe-*.pax",
        'build-name'   : buildName,
        'build-number' : env.BUILD_NUMBER
      ])
      cliSourceBuildInfo = pipeline.artifactory.getArtifact([
          'pattern'      : "${ZOWE_CLI_BUILD_REPOSITORY}/*/zowe-cli-package-*.zip",
          'build-name'   : ZOWE_CLI_BUILD_NAME
      ])
      if (sourceRegBuildInfo && sourceRegBuildInfo.path) { //run tests when sourceRegBuildInfo exists
        def testParameters = [
          booleanParam(name: 'STARTED_BY_AUTOMATION', value: true),
          string(name: 'TEST_SCOPE', value: 'bundle: convenience build on multiple security systems'),
          string(name: 'ZOWE_ARTIFACTORY_PATTERN', value: sourceRegBuildInfo.path),
          string(name: 'ZOWE_ARTIFACTORY_BUILD', value: buildName),
          string(name: 'INSTALL_TEST_DEBUG_INFORMATION', value: 'zowe-install-test:*'),
          string(name: 'SANITY_TEST_DEBUG_INFORMATION', value: 'zowe-sanity-test:*'),
          booleanParam(name: 'Skip Stage: Lint', value: true),
          booleanParam(name: 'Skip Stage: Audit', value: true),
          booleanParam(name: 'Skip Stage: SonarQube Scan', value: true)
        ]
        if (cliSourceBuildInfo && cliSourceBuildInfo.path) {
          testParameters.add(string(name: 'ZOWE_CLI_ARTIFACTORY_PATTERN', value: cliSourceBuildInfo.path))
          testParameters.add(string(name: 'ZOWE_CLI_ARTIFACTORY_BUILD', value: ''))
        }

        def test_result = build(
          job: '/zowe-install-test/staging',
          parameters: testParameters
        )
        echo "Test result: ${test_result.result}"
        if (test_result.result != 'SUCCESS') {
          currentBuild.result='UNSTABLE'
          if (test_result.result == 'ABORTED') {
            echo "Test aborted"
          } else {
            echo "Test failed on regular build ${sourceRegBuildInfo.path}, check failure details at ${test_result.absoluteUrl}"
          }
        }
      }
    }
  )

  pipeline.end()
}
