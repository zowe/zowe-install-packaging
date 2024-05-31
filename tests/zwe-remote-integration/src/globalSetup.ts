/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import * as uss from './zos/Uss';
import * as _ from 'lodash';
import * as path from 'path';
import * as files from '@zowe/zos-files-for-zowe-sdk';
import {
  DOWNLOAD_CONFIGMGR,
  DOWNLOAD_ZOWE_TOOLS,
  JFROG_CREDENTIALS,
  REMOTE_SETUP,
  REMOTE_SYSTEM_INFO,
  REPO_ROOT_DIR,
  LINGERING_REMOTE_FILES_FILE,
  TEST_JOBS_RUN_FILE,
  TEST_OUTPUT_DIR,
  THIS_TEST_BASE_YAML,
  THIS_TEST_ROOT_DIR,
  ZOWE_YAML_OVERRIDES,
} from './config/TestConfig';
import * as fs from 'fs-extra';
import { getSession } from './zos/ZosmfSession';
import * as yaml from 'yaml';
import ZoweYamlType from './config/ZoweYamlType';
import { JfrogClient } from 'jfrog-client-js';
import { processManifestVersion } from './utils';
import { execSync } from 'child_process';

const zosmfSession = getSession();

function setupBaseYaml() {
  console.log(`Using example-zowe.yaml as base for future zowe.yaml modifications...`);
  const zoweYaml: ZoweYamlType = yaml.parse(fs.readFileSync(`${REPO_ROOT_DIR}/example-zowe.yaml`, 'utf8')) as ZoweYamlType;

  zoweYaml.java.home = REMOTE_SYSTEM_INFO.zosJavaHome;
  zoweYaml.node.home = REMOTE_SYSTEM_INFO.zosNodeHome;
  zoweYaml.zowe.runtimeDirectory = REMOTE_SYSTEM_INFO.ussTestDir;
  zoweYaml.zowe.setup.dataset.prefix = REMOTE_SYSTEM_INFO.prefix;
  zoweYaml.zowe.setup.dataset.jcllib = REMOTE_SYSTEM_INFO.jcllib;
  zoweYaml.zowe.setup.vsam.name = REMOTE_SYSTEM_INFO.prefix + '.VSAM';
  zoweYaml.zowe.setup.vsam.volume = REMOTE_SYSTEM_INFO.volume;
  zoweYaml.zowe.setup.certificate.pkcs12.directory = REMOTE_SYSTEM_INFO.ussTestDir;
  // zoweYaml.zowe.setup.dataset.loadlib = REMOTE_SYSTEM_INFO.szweexec;
  // zoweYaml.node.home = systemDefaults.zos_node_home;
  // zoweYaml.zowe.runtimeDirectory = systemDefaults.

  //
  const finalYaml = _.merge({}, zoweYaml, ZOWE_YAML_OVERRIDES);

  fs.writeFileSync(THIS_TEST_BASE_YAML, yaml.stringify(finalYaml));
}

const jf = new JfrogClient({
  platformUrl: 'https://zowe.jfrog.io/',
  username: JFROG_CREDENTIALS.user,
  accessToken: JFROG_CREDENTIALS.token,
});

async function downloadManifestDep(binaryName: string): Promise<string> {
  const manifestJson = fs.readJSONSync(`${REPO_ROOT_DIR}/manifest.json.template`, 'utf8');
  const binaryDep = manifestJson['binaryDependencies'][binaryName];
  const dlSpec = processManifestVersion(binaryDep.version);
  const nameMatch = binaryDep?.artifact || '*';

  // get folders so we can regex against
  const pathMatch = `${binaryName.replace(/\./g, '/')}/${dlSpec.versionPattern}`;

  const searchResults = await jf
    .artifactory()
    .search()
    .aqlSearch(
      `
      items.find({
        "repo": "${dlSpec.repository}",
        "path": {"$match": "${pathMatch}"},
        "name": {"$match": "${nameMatch}" }
      }).sort({"$desc" : ["created"]}).limit(1)
      
    `.replace(/\s/g, ''),
    );
  if (searchResults.results == null || searchResults.results.length === 0) {
    throw new Error(`Could not find a ${binaryDep} matching the manifest.json spec`);
  }
  const artifact = searchResults.results[0];
  const dlFile = `${THIS_TEST_ROOT_DIR}/.build/${artifact.name}`;
  await jf.artifactory().download().downloadArtifactToFile(`${artifact.repo}/${artifact.path}/${artifact.name}`, dlFile);
  return dlFile;
}

async function cleanUssDir(dir: string) {
  console.log(`Checking if ${dir} is clean...`);
  const lsOut = await uss.runCommand(`ls ${dir}`);
  if (lsOut.rc === 0) {
    // already exists
    console.log(`Cleaning up old ${dir}...`);
    await uss.runCommand(`rm -rf ${dir}`);
  }
}

module.exports = async () => {
  // check directories and configmgr look OK
  if (!fs.existsSync(`${REPO_ROOT_DIR}/bin/zwe`)) {
    throw new Error('Could not locate the zwe tool locally. Ensure you are running tests from the test project root');
  }
  fs.mkdirpSync(`${THIS_TEST_ROOT_DIR}/.build`);
  setupBaseYaml();
  fs.rmSync(LINGERING_REMOTE_FILES_FILE, { force: true });
  fs.rmSync(TEST_JOBS_RUN_FILE, { force: true });
  fs.rmSync(TEST_OUTPUT_DIR, { force: true, recursive: true });
  fs.mkdirpSync(TEST_OUTPUT_DIR);

  if (REMOTE_SETUP) {
    if (DOWNLOAD_CONFIGMGR) {
      await downloadManifestDep('org.zowe.configmgr');
      await downloadManifestDep('org.zowe.configmgr-rexx');
    }
    if (DOWNLOAD_ZOWE_TOOLS) {
      await downloadManifestDep('org.zowe.utility-tools');
    }

    const configmgrPax = fs.readdirSync(`${THIS_TEST_ROOT_DIR}/.build`).find((item) => /configmgr.*\.pax/g.test(item));
    if (configmgrPax == null) {
      throw new Error('Could not locate a configmgr pax in the .build directory');
    }

    const configmgrRexxPax = fs.readdirSync(`${THIS_TEST_ROOT_DIR}/.build`).find((item) => /configmgr-rexx.*\.pax/g.test(item));
    if (configmgrRexxPax == null) {
      throw new Error('Could not locate a configmgr-rexx pax in the .build directory');
    }

    const zoweToolsZip = fs.readdirSync(`${THIS_TEST_ROOT_DIR}/.build`).find((item) => /zowe-utility-tools.*\.zip/g.test(item));
    if (zoweToolsZip == null) {
      throw new Error('Could not locate zowe-utility-tools zip in the .build directory');
    }

    console.log('Setting up remote server...');
    await uss.runCommand(`mkdir -p ${REMOTE_SYSTEM_INFO.ussTestDir}`);

    console.log(`Uploading ${configmgrPax} to ${REMOTE_SYSTEM_INFO.ussTestDir}/configmgr.pax ...`);
    await files.Upload.fileToUssFile(
      zosmfSession,
      `${THIS_TEST_ROOT_DIR}/.build/${configmgrPax}`,
      `${REMOTE_SYSTEM_INFO.ussTestDir}/configmgr.pax`,
      { binary: true },
    );

    console.log(`Uploading ${configmgrRexxPax} to ${REMOTE_SYSTEM_INFO.ussTestDir}/configmgr-rexx.pax ...`);
    await files.Upload.fileToUssFile(
      zosmfSession,
      `${THIS_TEST_ROOT_DIR}/.build/${configmgrRexxPax}`,
      `${REMOTE_SYSTEM_INFO.ussTestDir}/configmgr-rexx.pax`,
      { binary: true },
    );

    console.log(`Building zwe typescript...`);
    execSync(`npm install && npm run prod`, { cwd: `${REPO_ROOT_DIR}/build/zwe` });

    await cleanUssDir(`${REMOTE_SYSTEM_INFO.ussTestDir}/bin`);
    await cleanUssDir(`${REMOTE_SYSTEM_INFO.ussTestDir}/schemas`);

    console.log(`Uploading conversion script...`);
    await files.Upload.fileToUssFile(
      zosmfSession,
      `${THIS_TEST_ROOT_DIR}/resources/convert_to_ebcdic.sh`,
      `${REMOTE_SYSTEM_INFO.ussTestDir}/convert_to_ebcdic.sh`,
    );

    console.log(`Uploading ${REPO_ROOT_DIR}/bin to ${REMOTE_SYSTEM_INFO.ussTestDir}/bin...`);
    // archive without compression (issues on some backends)
    execSync(`tar -cf ${THIS_TEST_ROOT_DIR}/.build/zwe.tar -C ${REPO_ROOT_DIR} bin`);
    await files.Upload.fileToUssFile(
      zosmfSession,
      `${THIS_TEST_ROOT_DIR}/.build/zwe.tar`,
      `${REMOTE_SYSTEM_INFO.ussTestDir}/zwe.tar`,
      {
        binary: true,
      },
    );
    await uss.runCommand(`tar -xf zwe.tar`, REMOTE_SYSTEM_INFO.ussTestDir);

    // zowe-install-packaging-tools
    const utilsDir = path.resolve(THIS_TEST_ROOT_DIR, '.build', 'utility-tools');
    fs.mkdirpSync(`${utilsDir}`);
    execSync(`unzip -o ${THIS_TEST_ROOT_DIR}/.build/${zoweToolsZip} -d ${utilsDir}`, { cwd: THIS_TEST_ROOT_DIR });

    for (const file of fs.readdirSync(utilsDir)) {
      const match = file.match(/zowe-(.*)-[0-9]?.*tgz/im);
      if (match) {
        const fileName = match[0];
        const pkgName = match[1];

        console.log(`Uploading ${pkgName} to ${REMOTE_SYSTEM_INFO.ussTestDir}/bin/utils...`);
        // re-archive without compression (issues on some backends)
        execSync(`tar xzf ${fileName} && tar -cf ${pkgName}.tar package && rm -rf package`, { cwd: utilsDir });
        await files.Upload.fileToUssFile(
          zosmfSession,
          `${utilsDir}/${pkgName}.tar`,
          `${REMOTE_SYSTEM_INFO.ussTestDir}/${pkgName}.tar`,
          {
            binary: true,
          },
        );
        await uss.runCommand(`tar xf ${pkgName}.tar`, REMOTE_SYSTEM_INFO.ussTestDir);
        await uss.runCommand(`mv package ./bin/utils/${pkgName}`, REMOTE_SYSTEM_INFO.ussTestDir);
      }
    }
    let ncertPax = '';
    console.log(`Uploading ncert to ${REMOTE_SYSTEM_INFO.ussTestDir}/bin/utils...`);
    fs.readdirSync(`${THIS_TEST_ROOT_DIR}/.build/utility-tools`).forEach((item) => {
      const match = item.match(/zowe-ncert-([0-9]?.*)\.pax/im);
      if (match && match[1]) {
        ncertPax = match[0];
      }
    });
    await files.Upload.fileToUssFile(
      zosmfSession,
      `${THIS_TEST_ROOT_DIR}/.build/utility-tools/${ncertPax}`,
      `${REMOTE_SYSTEM_INFO.ussTestDir}/ncert.pax`,
      {
        binary: true,
      },
    );

    console.log(`Converting everything in ${REMOTE_SYSTEM_INFO.ussTestDir}/bin to EBCDIC...`);
    await uss.runCommand(`chmod +x convert_to_ebcdic.sh && ./convert_to_ebcdic.sh`, REMOTE_SYSTEM_INFO.ussTestDir);

    console.log(`Uploading ${REPO_ROOT_DIR}/schemas to ${REMOTE_SYSTEM_INFO.ussTestDir}/schemas...`);
    await files.Upload.dirToUSSDirRecursive(zosmfSession, `${REPO_ROOT_DIR}/schemas`, `${REMOTE_SYSTEM_INFO.ussTestDir}/schemas/`, {
      binary: false,
      includeHidden: true,
    });

    console.log(`Uploading ${REPO_ROOT_DIR}/files/defaults.yaml to ${REMOTE_SYSTEM_INFO.ussTestDir}...`);
    await uss.runCommand(`mkdir -p ${REMOTE_SYSTEM_INFO.ussTestDir}/files`);
    await files.Upload.fileToUssFile(
      zosmfSession,
      `${REPO_ROOT_DIR}/files/defaults.yaml`,
      `${REMOTE_SYSTEM_INFO.ussTestDir}/files/defaults.yaml`,
      {
        binary: false,
      },
    );

    await createPds(REMOTE_SYSTEM_INFO.szweexec, {
      primary: 5,
      secondary: 1,
    });
    await createPds(REMOTE_SYSTEM_INFO.szwesamp, {
      primary: 5,
      secondary: 1,
    });
    await createPds(REMOTE_SYSTEM_INFO.szweload, {
      primary: 5,
      recfm: 'U',
      lrecl: 0,
      secondary: 1,
    });

    console.log(`Unpacking configmgr and placing it in bin/utils ...`);
    await uss.runCommand(`pax -ppx -rf configmgr.pax && mv configmgr bin/utils/`, `${REMOTE_SYSTEM_INFO.ussTestDir}`);

    console.log(`Unpacking configmgr-rexx and placing it in ${REMOTE_SYSTEM_INFO.szweload} ...`);
    await uss.runCommand(`pax -ppx -rf configmgr-rexx.pax`, `${REMOTE_SYSTEM_INFO.ussTestDir}`);
    for (const pgm of ['ZWERXCFG', 'ZWECFG31', 'ZWECFG64']) {
      await uss.runCommand(`cp -X ${pgm} "//'${REMOTE_SYSTEM_INFO.szweload}(${pgm})'"`, `${REMOTE_SYSTEM_INFO.ussTestDir}`);
    }

    console.log(`Unpacking ncert.pax from zowe-install-packaging-tools and placing it in bin/utils/...`);
    await uss.runCommand(`pax -ppx -rf ncert.pax -s#^#./bin/utils/ncert/#g`, `${REMOTE_SYSTEM_INFO.ussTestDir}`);

    console.log(`Compiling Java utilities in bin/utils using ${REMOTE_SYSTEM_INFO.zosJavaHome}...`);
    await uss.runCommand(`${REMOTE_SYSTEM_INFO.zosJavaHome}/bin/javac *.java`, `${REMOTE_SYSTEM_INFO.ussTestDir}/bin/utils`);

    console.log(`Uploading sample JCL from files/SZWESAMP to ${REMOTE_SYSTEM_INFO.szwesamp}...`);
    await files.Upload.dirToPds(zosmfSession, `${REPO_ROOT_DIR}/files/SZWESAMP`, REMOTE_SYSTEM_INFO.szwesamp, {
      binary: false,
    });

    console.log(`Uploading JCL from files/SZWEEXEC to ${REMOTE_SYSTEM_INFO.szweexec}...`);
    await files.Upload.dirToPds(zosmfSession, `${REPO_ROOT_DIR}/files/SZWEEXEC`, REMOTE_SYSTEM_INFO.szweexec, {
      binary: false,
    });

    console.log('Remote server setup complete');
  }
};

async function createPds(pdsName: string, createOpts: Partial<files.ICreateDataSetOptions>) {
  const defaultPdsOpts: files.ICreateDataSetOptions = {
    lrecl: 80,
    recfm: 'FB',
    blksize: 32720,
    alcunit: 'cyl',
    primary: 10,
    secondary: 2,
    dsorg: 'PO',
    dsntype: 'library',
    volser: REMOTE_SYSTEM_INFO.volume,
  };
  const mergedOpts: Partial<files.ICreateDataSetOptions> = _.merge({}, defaultPdsOpts, createOpts);
  console.log(`Creating ${pdsName}`);
  await createDataset(pdsName, files.CreateDataSetTypeEnum.DATA_SET_PARTITIONED, mergedOpts);
}

async function createDataset(dsName: string, type: files.CreateDataSetTypeEnum, createOpts: Partial<files.ICreateDataSetOptions>) {
  console.log(`Checking if ${dsName} exists...`);
  const listPdsResp = await files.List.dataSet(zosmfSession, dsName, {
    pattern: dsName,
  });
  console.log(JSON.stringify(listPdsResp));
  const respItems: { [key: string]: string }[] = listPdsResp.apiResponse?.items;
  if (respItems != null && respItems.find((item) => item.dsname === dsName) != null) {
    console.log(`Pds exists, cleaning up...`);
    await files.Delete.dataSet(zosmfSession, dsName, {});
  }
  console.log(`Creating ${dsName}`);
  await files.Create.dataSet(zosmfSession, type, dsName, createOpts);
}
