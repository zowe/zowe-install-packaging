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
import EBCDIC from 'ebcdic-ascii';
import * as tar from 'tar';
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
  THIS_TEST_BASE_ZOWE_YAML,
  THIS_TEST_ROOT_DIR,
  ZOWE_YAML_OVERRIDES,
  THIS_TEST_BASE_DEFAULTS_YAML,
  DOWNLOAD_SZWESAMP,
} from './config/TestConfig';
import * as fs from 'fs-extra';
import { getSession } from './zos/ZosmfSession';
import * as yaml from 'yaml';
import ZoweYamlType from './config/ZoweYamlType';
import { JfrogClient } from 'jfrog-client-js';
import { processManifestVersion } from './utils';
import { execSync } from 'child_process';
import { createPds } from './zos/Files';

const zosmfSession = getSession();
const buildDir = path.resolve(THIS_TEST_ROOT_DIR, '.build');
const downloadsDir = path.resolve(buildDir, 'downloads');

function setupBaseYaml() {
  console.log(`Using example-zowe.yaml as base for future zowe.yaml modifications...`);
  const zoweYaml: ZoweYamlType = yaml.parse(fs.readFileSync(path.resolve(REPO_ROOT_DIR, 'example-zowe.yaml'), 'utf8')) as ZoweYamlType;

  zoweYaml.java.home = REMOTE_SYSTEM_INFO.zosJavaHome;
  zoweYaml.node.home = REMOTE_SYSTEM_INFO.zosNodeHome;
  zoweYaml.zowe.runtimeDirectory = REMOTE_SYSTEM_INFO.ussTestDir;
  zoweYaml.zowe.logDirectory = REMOTE_SYSTEM_INFO.zweLogDir;
  zoweYaml.zowe.workspaceDirectory = REMOTE_SYSTEM_INFO.zweWorkspaceDir;
  zoweYaml.zowe.setup.dataset.prefix = REMOTE_SYSTEM_INFO.prefix;
  zoweYaml.zowe.setup.dataset.jcllib = REMOTE_SYSTEM_INFO.jcllib;
  zoweYaml.zowe.setup.dataset.proclib = REMOTE_SYSTEM_INFO.proclib;
  zoweYaml.zowe.setup.vsam.name = REMOTE_SYSTEM_INFO.prefix + '.VSAM';
  zoweYaml.zowe.setup.vsam.volume = REMOTE_SYSTEM_INFO.volume;
  zoweYaml.zOSMF.host = REMOTE_SYSTEM_INFO.hostname;
  zoweYaml.zOSMF.port = Number(REMOTE_SYSTEM_INFO.zosmfPort);
  // @ts-expect-error incomplete schema
  zoweYaml.zowe.setup.certificate.pkcs12.directory = `${REMOTE_SYSTEM_INFO.ussTestDir}/pkcs12`;
  zoweYaml.zowe.setup.dataset.authLoadlib = REMOTE_SYSTEM_INFO.authLoadLib;
  zoweYaml.zowe.setup.dataset.authPluginLib = REMOTE_SYSTEM_INFO.authPluginLib;
  zoweYaml.zowe.setup.dataset.parmlib = REMOTE_SYSTEM_INFO.parmlib;
  zoweYaml.zowe.setup.dataset.loadlib = REMOTE_SYSTEM_INFO.szweexec;
  // zoweYaml.node.home = systemDefaults.zos_node_home;
  // zoweYaml.zowe.runtimeDirectory = systemDefaults.

  //
  const finalYaml = _.merge({}, zoweYaml, ZOWE_YAML_OVERRIDES);

  fs.writeFileSync(THIS_TEST_BASE_ZOWE_YAML, yaml.stringify(finalYaml, { nullStr: '' }));

  console.log(`Using files/defaults.yaml as base for future defaults.yaml modifications...`);
  const defaultsYaml: ZoweYamlType = yaml.parse(
    fs.readFileSync(path.resolve(REPO_ROOT_DIR, 'files', 'defaults.yaml'), 'utf8'),
  ) as ZoweYamlType;
  fs.writeFileSync(THIS_TEST_BASE_DEFAULTS_YAML, yaml.stringify(defaultsYaml, { nullStr: '' }));
}

const jf = new JfrogClient({
  platformUrl: 'https://zowe.jfrog.io/',
  username: JFROG_CREDENTIALS.user,
  accessToken: JFROG_CREDENTIALS.token,
});

async function downloadArtifact(repo: string, artifactPath: string, artifactName: string): Promise<string> {
  const searchResults = await jf
    .artifactory()
    .search()
    .aqlSearch(
      `
    items.find({
      "repo": "${repo}",
      "path": {"$match": "${artifactPath}"},
      "name": {"$match": "${artifactName}" }
    }).sort({"$desc" : ["created"]}).limit(1)
    
  `.replace(/\s/g, ''),
    );
  if (searchResults.results == null || searchResults.results.length === 0) {
    throw new Error(
      `Could not find in Artifactory the following binary dependency specified by manifest.json.\n ${repo}:${path}:${artifactName}\n`,
    );
  }
  const artifact = searchResults.results[0];
  const dlFile = path.resolve(downloadsDir, artifact.name);
  await jf.artifactory().download().downloadArtifactToFile(`${artifact.repo}/${artifact.path}/${artifact.name}`, dlFile);
  return dlFile;
}

async function downloadManifestDep(binaryName: string): Promise<string> {
  const manifestJson = fs.readJSONSync(path.resolve(REPO_ROOT_DIR, 'manifest.json.template'), 'utf8');
  const binaryDep = manifestJson['binaryDependencies'][binaryName];
  const dlSpec = processManifestVersion(binaryDep.version);
  const nameMatch = binaryDep?.artifact || '*';

  // get folders so we can regex against
  const pathMatch = `${binaryName.replace(/\./g, '/')}/${dlSpec.versionPattern}`;

  console.log(`
    items.find({
      "repo": "${dlSpec.repository}",
      "path": {"$match": "${pathMatch}"},
      "name": {"$match": "${nameMatch}" }
    }).sort({"$desc" : ["created"]}).limit(1)
    
  `);
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
    throw new Error(
      `Could not find in Artifactory the following binary dependency specified by manifest.json.\n ${JSON.stringify(binaryDep)}\n`,
    );
  }
  const artifact = searchResults.results[0];
  const dlFile = path.resolve(downloadsDir, artifact.name);
  await jf.artifactory().download().downloadArtifactToFile(`${artifact.repo}/${artifact.path}/${artifact.name}`, dlFile);
  return dlFile;
}

async function cleanUssDir(dir: string) {
  console.log(`Checking if ${dir} is clean...`);
  const lsOut = await uss.runCommand(`ls ${dir}`);
  if (lsOut.rc === 0) {
    // already exists
    console.log(`-->Cleaning up old ${dir}...`);
    await uss.runCommand(`rm -rf ${dir}`);
  }
}

module.exports = async () => {
  const ussWorkDir = `${REMOTE_SYSTEM_INFO.ussTestDir}/.setup`;
  // check directories and configmgr look OK
  const zwePath = path.resolve(REPO_ROOT_DIR, 'bin', 'zwe');
  const zweBuildPath = path.resolve(REPO_ROOT_DIR, 'build', 'zwe');

  if (!fs.existsSync(zwePath)) {
    throw new Error('Could not locate the zwe tool locally. Ensure you are running tests from the test project root');
  }

  fs.mkdirpSync(buildDir);
  fs.mkdirpSync(downloadsDir);

  setupBaseYaml();
  fs.rmSync(LINGERING_REMOTE_FILES_FILE, { force: true });
  fs.rmSync(TEST_JOBS_RUN_FILE, { force: true });
  fs.rmSync(TEST_OUTPUT_DIR, { force: true, recursive: true });
  fs.mkdirpSync(TEST_OUTPUT_DIR);

  if (REMOTE_SETUP) {
    // we're downloading everything, so take the opportunity to clean up old files
    if (DOWNLOAD_CONFIGMGR && DOWNLOAD_SZWESAMP && DOWNLOAD_ZOWE_TOOLS) {
      fs.rmSync(downloadsDir, { force: true, recursive: true });
      fs.mkdirSync(downloadsDir);
    }
    if (DOWNLOAD_CONFIGMGR) {
      await downloadManifestDep('org.zowe.configmgr');
      await downloadManifestDep('org.zowe.configmgr-rexx');
    }

    if (DOWNLOAD_SZWESAMP) {
      await downloadManifestDep('org.zowe.launcher');
      await downloadManifestDep('org.zowe.zss');
    }

    if (DOWNLOAD_ZOWE_TOOLS) {
      await downloadManifestDep('org.zowe.keyring-utilities');
      await downloadManifestDep('org.zopencommunity.curl');
      await downloadManifestDep('org.zowe.getesm');
    }

    await downloadArtifact('libs-snapshot-local', 'org/zowe/vtl-cli/zowe-cli-package/1.0.7-SNAPSHOT', 'vtl.tar.gz');

    const downloadsDirContents = fs.readdirSync(downloadsDir);

    const launcherPax = downloadsDirContents.find((item) => /launcher.*\.pax/g.test(item));
    if (launcherPax == null) {
      throw new Error('Could not locate a launcher pax in the .build directory');
    }

    const configmgrPax = downloadsDirContents.find((item) => /configmgr.*\.pax/g.test(item));
    if (configmgrPax == null) {
      throw new Error('Could not locate a configmgr pax in the .build directory');
    }

    const configmgrRexxPax = downloadsDirContents.find((item) => /configmgr-rexx.*\.pax/g.test(item));
    if (configmgrRexxPax == null) {
      throw new Error('Could not locate a configmgr-rexx pax in the .build directory');
    }

    const zssPax = downloadsDirContents.find((item) => /zss-.*\.pax/g.test(item));
    if (zssPax == null) {
      throw new Error('Could not locate a zss pax in the .build directory');
    }

    const curlPax = downloadsDirContents.find((item) => /curl.*\.pax.Z/g.test(item));
    if (curlPax == null) {
      throw new Error('Could not locate the curl pax in the .build directory');
    }

    const keyringUtilPax = downloadsDirContents.find((item) => /keyring-util.*\.pax/g.test(item));
    if (keyringUtilPax == null) {
      throw new Error('Could not locate keyring-utilities pax in the .build directory');
    }

    const vtlArchive = downloadsDirContents.find((item) => /vtl.tar.gz/g.test(item));
    if (vtlArchive == null) {
      throw new Error('Could not locate vtl archive in the .build directory');
    }

    const getEsmArchive = downloadsDirContents.find((item) => /getesm.*.pax/g.test(item));
    if (getEsmArchive == null) {
      throw new Error('Could not locate the getesm pax in the .build directory');
    }

    console.log(`Setting up remote server on ${REMOTE_SYSTEM_INFO.hostname}...`);
    await uss.runCommand(`mkdir -p ${REMOTE_SYSTEM_INFO.ussTestDir} && mkdir -p ${ussWorkDir}`);

    // zowe-install-packaging-tools and vtl-cli
    const utilsDir = path.resolve(buildDir, 'utils');
    fs.mkdirpSync(`${utilsDir}`);

    console.log(`Repacking vtl-cli....`);
    tar.x({ f: path.resolve(downloadsDir, vtlArchive), C: utilsDir, sync: true }, []);
    const finalVtlPkg = path.resolve(utilsDir, 'vtl-cli.tar');
    // Re-pack without compression which can cause issues on backend
    tar.c({ gzip: false, file: finalVtlPkg, cwd: utilsDir, sync: true }, ['vtl', 'vtl-cli.jar', 'zos']);

    console.log(`Uploading ${finalVtlPkg} to ${ussWorkDir}/${path.basename(finalVtlPkg)}...`);
    await files.Upload.fileToUssFile(zosmfSession, finalVtlPkg, `${ussWorkDir}/${path.basename(finalVtlPkg)}`, {
      binary: true,
    });

    console.log(`Uploading ${configmgrPax} to ${ussWorkDir}/configmgr.pax ...`);
    await files.Upload.fileToUssFile(zosmfSession, path.resolve(downloadsDir, configmgrPax), `${ussWorkDir}/configmgr.pax`, {
      binary: true,
    });

    console.log(`Uploading ${configmgrRexxPax} to ${ussWorkDir}/configmgr-rexx.pax ...`);
    await files.Upload.fileToUssFile(zosmfSession, path.resolve(downloadsDir, configmgrRexxPax), `${ussWorkDir}/configmgr-rexx.pax`, {
      binary: true,
    });

    console.log(`Uploading ${zssPax} to ${ussWorkDir}/zss.pax ...`);
    await files.Upload.fileToUssFile(zosmfSession, path.resolve(downloadsDir, zssPax), `${ussWorkDir}/zss.pax`, {
      binary: true,
    });

    console.log(`Uploading ${launcherPax} to ${ussWorkDir}/launcher.pax ...`);
    await files.Upload.fileToUssFile(zosmfSession, path.resolve(downloadsDir, launcherPax), `${ussWorkDir}/${launcherPax}`, {
      binary: true,
    });

    console.log(`Uploading ${curlPax} to ${ussWorkDir}/curl.pax.Z ...`);
    await files.Upload.fileToUssFile(zosmfSession, path.resolve(downloadsDir, curlPax), `${ussWorkDir}/${curlPax}`, {
      binary: true,
    });

    console.log(`Uploading ${keyringUtilPax} to ${ussWorkDir}/keyring-util.pax...`);
    await files.Upload.fileToUssFile(zosmfSession, path.resolve(downloadsDir, keyringUtilPax), `${ussWorkDir}/${keyringUtilPax}`, {
      binary: true,
    });

    console.log(`Building zwe typescript...`);
    execSync(`npm install && npm run prod`, { cwd: zweBuildPath });

    await cleanUssDir(`${REMOTE_SYSTEM_INFO.ussTestDir}/bin`);
    await cleanUssDir(`${REMOTE_SYSTEM_INFO.ussTestDir}/schemas`);

    console.log(`Uploading ${REPO_ROOT_DIR}/bin to ${REMOTE_SYSTEM_INFO.ussTestDir}/bin...`);

    // archive without compression (issues on some backends)
    const tarFile = path.resolve(buildDir, 'zwe.tar');
    fs.cpSync(path.resolve(REPO_ROOT_DIR, 'bin'), path.resolve(buildDir, 'bin'), { force: true, recursive: true });
    console.log('Converting bin to ebcdic locally, then uploading and unpacking...');
    convertDirToEbcdicInPlace(path.resolve(buildDir, 'bin'));
    tar.c({ gzip: false, file: tarFile, sync: true, cwd: buildDir }, ['bin']);
    await files.Upload.fileToUssFile(zosmfSession, tarFile, `${ussWorkDir}/zwe.tar`, {
      binary: true,
    });
    await uss.runCommand(`tar -xfo ${ussWorkDir}/zwe.tar`, REMOTE_SYSTEM_INFO.ussTestDir);

    await uss.runCommand(
      `chmod 755 ${REMOTE_SYSTEM_INFO.ussTestDir}/bin/zwe && ` + `chmod 755 ${REMOTE_SYSTEM_INFO.ussTestDir}/bin/utils/opercmd.rex `,
      REMOTE_SYSTEM_INFO.ussTestDir,
    );

    console.log(`Uploading getesm pax tp ${ussWorkDir}/${getEsmArchive}...`);
    await files.Upload.fileToUssFile(zosmfSession, path.resolve(downloadsDir, getEsmArchive), `${ussWorkDir}/${getEsmArchive}`, {
      binary: true,
    });
    await uss.runCommand(`pax -ppx -rf ${getEsmArchive} && cp -f getesm ${REMOTE_SYSTEM_INFO.ussTestDir}/bin/utils`, ussWorkDir);

    console.log(`Unpacking ${curlPax} and moving curl to ${REMOTE_SYSTEM_INFO.ussTestDir}/bin/utils...`);
    await uss.runCommand(`pax -ppx -rf ${curlPax} && cp -f curl-*/bin/curl ${REMOTE_SYSTEM_INFO.ussTestDir}/bin/utils`, ussWorkDir);

    console.log(`Unpacking ${keyringUtilPax} and moving keyring-util to ${REMOTE_SYSTEM_INFO.ussTestDir}/bin/utils...`);
    await uss.runCommand(
      `pax -ppx -rf ${keyringUtilPax} && cp -f keyring-util ${REMOTE_SYSTEM_INFO.ussTestDir}/bin/utils`,
      ussWorkDir,
    );

    console.log(`Uploading ${REPO_ROOT_DIR}/schemas to ${REMOTE_SYSTEM_INFO.ussTestDir}/schemas...`);
    await files.Upload.dirToUSSDirRecursive(
      zosmfSession,
      path.resolve(REPO_ROOT_DIR, 'schemas'),
      `${REMOTE_SYSTEM_INFO.ussTestDir}/schemas/`,
      {
        binary: false,
        includeHidden: true,
      },
    );

    console.log(`Uploading ${REPO_ROOT_DIR}/files/defaults.yaml to ${REMOTE_SYSTEM_INFO.ussTestDir}...`);
    await uss.runCommand(`mkdir -p ${REMOTE_SYSTEM_INFO.ussTestDir}/files`);
    await files.Upload.fileToUssFile(
      zosmfSession,
      path.resolve(REPO_ROOT_DIR, 'files', 'defaults.yaml'),
      `${REMOTE_SYSTEM_INFO.ussTestDir}/files/defaults.yaml`,
      {
        binary: false,
      },
    );

    console.log(`Uploading ${REPO_ROOT_DIR}/workflows/templates/ZWESECUR.vtl and ZWESECUR.properties to ${ussWorkDir}...`);
    await files.Upload.fileToUssFile(
      zosmfSession,
      path.resolve(REPO_ROOT_DIR, 'workflows', 'templates', 'ZWESECUR.vtl'),
      `${ussWorkDir}/ZWESECUR.vtl`,
      {
        binary: false,
      },
    );

    await files.Upload.fileToUssFile(
      zosmfSession,
      path.resolve(REPO_ROOT_DIR, 'workflows', 'templates', 'ZWESECUR.properties'),
      `${ussWorkDir}/ZWESECUR.properties`,
      {
        binary: false,
      },
    );

    const simplePdsParams = { primary: 5, secondary: 1, volser: REMOTE_SYSTEM_INFO.volume };
    const loadlibParams = { primary: 5, recfm: 'U', lrecl: 0, secondary: 1, volser: REMOTE_SYSTEM_INFO.volume };
    await createPds(REMOTE_SYSTEM_INFO.szweexec, simplePdsParams);
    await createPds(REMOTE_SYSTEM_INFO.szwesamp, simplePdsParams);
    await createPds(REMOTE_SYSTEM_INFO.szweload, loadlibParams);
    await createPds(REMOTE_SYSTEM_INFO.proclib, simplePdsParams);
    await createPds(REMOTE_SYSTEM_INFO.parmlib, simplePdsParams);
    await createPds(REMOTE_SYSTEM_INFO.authLoadLib, loadlibParams);
    await createPds(REMOTE_SYSTEM_INFO.authPluginLib, loadlibParams);

    console.log(`Unpacking configmgr and placing it in bin/utils ...`);
    await uss.runCommand(`pax -ppx -rf configmgr.pax && mv configmgr ${REMOTE_SYSTEM_INFO.ussTestDir}/bin/utils/`, ussWorkDir);

    console.log(`Unpacking configmgr-rexx and placing it in ${REMOTE_SYSTEM_INFO.szweload} ...`);
    await uss.runCommand(`pax -ppx -rf configmgr-rexx.pax`, ussWorkDir);
    for (const pgm of ['ZWERXCFG', 'ZWECFG31', 'ZWECFG64']) {
      await uss.runCommand(`cp -X ${pgm} "//'${REMOTE_SYSTEM_INFO.szweload}(${pgm})'"`, ussWorkDir);
    }

    console.log(`Unpacking zss pax and placing SAMPLIB in ${REMOTE_SYSTEM_INFO.szwesamp} ...`);
    await uss.runCommand(`pax -ppx -rf zss.pax`, ussWorkDir);
    const zssPgms = [
      { from: 'ZWESIP00', to: 'ZWESIP00' },
      { from: 'ZWESISCH', to: 'ZWESISCH' },
      { from: 'ZWESASTC', to: 'ZWESASTC' },
      { from: 'ZWESISTC', to: 'ZWESISTC' },
    ];
    for (const pgm of zssPgms) {
      const resp = await uss.runCommand(`cp SAMPLIB/${pgm.from} "//'${REMOTE_SYSTEM_INFO.szwesamp}(${pgm.to})'"`, ussWorkDir);
      if (resp.rc !== 0) {
        throw new Error(`Failed to copy ${pgm.from} to ${pgm.to}`);
      }
    }

    console.log(`Unpacking launcher pax and placing SAMPLIB in ${REMOTE_SYSTEM_INFO.szwesamp} ...`);
    await uss.runCommand(`pax -ppx -rf launcher.pax`, ussWorkDir);
    await uss.runCommand(`cp bin/zowe_launcher ${REMOTE_SYSTEM_INFO.ussTestDir}/bin`, ussWorkDir);
    for (const pgm of ['ZWESLSTC']) {
      await uss.runCommand(`cp samplib/${pgm} "//'${REMOTE_SYSTEM_INFO.szwesamp}(${pgm})'"`, ussWorkDir);
    }

    console.log(`Unpacking ncert.pax from zowe-install-packaging-tools and placing it in bin/utils/...`);
    await uss.runCommand(`pax -ppx -rf ncert.pax -s#^#${REMOTE_SYSTEM_INFO.ussTestDir}/bin/utils/ncert/#g`, ussWorkDir);

    console.log(`Unpacking vtl-cli, generating ZWESECUR, and copying it to SZWESAMP`);
    await uss.runCommand(`tar -xf vtl-cli.tar && rm -rf vtl-cli && mkdir -p vtl-cli && mv vtl vtl-cli.jar zos vtl-cli`, ussWorkDir);
    await uss.runCommand(
      `${REMOTE_SYSTEM_INFO.zosJavaHome}/bin/java -jar ${ussWorkDir}/vtl-cli/vtl-cli.jar -ie Cp1140 --yaml-context ZWESECUR.properties ZWESECUR.vtl -oe Cp1140 > ZWESECUR.jcl`,
      ussWorkDir,
    );
    await uss.runCommand(`cp ${ussWorkDir}/ZWESECUR.jcl "//'${REMOTE_SYSTEM_INFO.szwesamp}(ZWESECUR)'"`);

    console.log(`Compiling Java utilities in bin/utils using ${REMOTE_SYSTEM_INFO.zosJavaHome}...`);
    await uss.runCommand(`${REMOTE_SYSTEM_INFO.zosJavaHome}/bin/javac *.java`, `${REMOTE_SYSTEM_INFO.ussTestDir}/bin/utils`);

    console.log(`Uploading sample JCL from files/SZWESAMP to ${REMOTE_SYSTEM_INFO.szwesamp}...`);
    await files.Upload.dirToPds(zosmfSession, path.resolve(REPO_ROOT_DIR, 'files', 'SZWESAMP'), REMOTE_SYSTEM_INFO.szwesamp, {
      binary: false,
    });

    console.log(`Uploading JCL from files/SZWEEXEC to ${REMOTE_SYSTEM_INFO.szweexec}...`);
    await files.Upload.dirToPds(zosmfSession, path.resolve(REPO_ROOT_DIR, 'files', 'SZWEEXEC'), REMOTE_SYSTEM_INFO.szweexec, {
      binary: false,
    });

    console.log(`Uploading manifest.json.template to manifest.json...`);
    await files.Upload.fileToUssFile(
      zosmfSession,
      path.resolve(REPO_ROOT_DIR, 'manifest.json.template'),
      `${REMOTE_SYSTEM_INFO.ussTestDir}/manifest.json`,
    );

    console.log('Remote server setup complete');
  }
};

function convertDirToEbcdicInPlace(dir: string) {
  const dirContents = fs.readdirSync(dir, { recursive: true });
  const converter = new EBCDIC('1047');
  for (const entry of dirContents) {
    const filePath = path.resolve(dir, entry.toString());
    const file = fs.lstatSync(filePath);
    if (file.isFile()) {
      const asHex = fs.readFileSync(filePath).toString('hex');
      const asciiChars = converter.splitHex(asHex).map((a) => a.toUpperCase());
      const asEbcdic = asciiChars
        .map((code: string) => {
          // Replace line feeds with new line, ignore carriage returns.
          // Both ascii characters ignored by converter out of the box.
          if (code === '0A') {
            return '15';
          } else {
            return converter.charToEBCDIC(code);
          }
        })
        .join('');
      fs.writeFileSync(filePath, Buffer.from(asEbcdic, 'hex'));
    }
  }
}
