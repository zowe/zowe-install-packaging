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
import { createPds, LOADLIB_PARAMS, SIMPLE_PDS_PARAMS } from './zos/Files';
import { convertDirToEbcdicInPlace } from './zos/EbcdicTools';

const zosmfSession = getSession();
const buildDir = path.resolve(THIS_TEST_ROOT_DIR, '.build');
const downloadsDir = path.resolve(buildDir, 'downloads');

function setupBaseYaml() {
  console.log(`Using example-zowe.yaml as base for future zowe.yaml modifications...`);
  const zoweYaml: ZoweYamlType = yaml.parse(fs.readFileSync(path.resolve(REPO_ROOT_DIR, 'example-zowe.yaml'), 'utf8')) as ZoweYamlType;

  zoweYaml.java.home = REMOTE_SYSTEM_INFO.zosJavaHome;
  delete zoweYaml.node;
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

type ManifestBinaryDeps = Record<string, { version: string; artifact?: string }>;

let manifestBinaryDepsCache: ManifestBinaryDeps | undefined;

function getManifestBinaryDeps(): ManifestBinaryDeps {
  if (manifestBinaryDepsCache == null) {
    const manifestJson = fs.readJSONSync(path.resolve(REPO_ROOT_DIR, 'manifest.json.template'), 'utf8') as {
      binaryDependencies: ManifestBinaryDeps;
    };
    manifestBinaryDepsCache = manifestJson.binaryDependencies;
  }
  return manifestBinaryDepsCache;
}

async function downloadFromArtifactory(repo: string, pathMatch: string, nameMatch: string, notFoundDetail: string): Promise<string> {
  const searchResults = await jf
    .artifactory()
    .search()
    .aqlSearch(
      `
      items.find({
        "repo": "${repo}",
        "path": {"$match": "${pathMatch}"},
        "name": {"$match": "${nameMatch}" }
      }).sort({"$desc" : ["created"]}).limit(1)
    `.replace(/\s/g, ''),
    );
  if (searchResults.results == null || searchResults.results.length === 0) {
    throw new Error(`Could not find in Artifactory the following binary dependency specified by manifest.json.\n ${notFoundDetail}\n`);
  }
  const artifact = searchResults.results[0];
  const dlFile = path.resolve(downloadsDir, artifact.name);
  await jf.artifactory().download().downloadArtifactToFile(`${artifact.repo}/${artifact.path}/${artifact.name}`, dlFile);
  return dlFile;
}

async function downloadArtifact(repo: string, artifactPath: string, artifactName: string): Promise<string> {
  return downloadFromArtifactory(repo, artifactPath, artifactName, `${repo}:${artifactPath}:${artifactName}`);
}

async function downloadManifestDep(binaryName: string): Promise<string> {
  const binaryDep = getManifestBinaryDeps()[binaryName];
  if (binaryDep == null) {
    throw new Error(`No binaryDependencies entry in manifest for ${binaryName}`);
  }
  const dlSpec = processManifestVersion(binaryDep.version);
  const nameMatch = binaryDep?.artifact || '*';
  const pathMatch = `${binaryName.replace(/\./g, '/')}/${dlSpec.versionPattern}`;
  return downloadFromArtifactory(dlSpec.repository, pathMatch, nameMatch, JSON.stringify(binaryDep));
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

type DownloadSpec =
  | { kind: 'manifest'; name: string; when?: () => boolean }
  | { kind: 'artifact'; repo: string; artifactPath: string; artifactName: string; when?: () => boolean };

/**
 * Keys for artifacts whose USS basename is the downloaded filename (see `useSourceBasename`) and
 * that basename is interpolated into later `uss.runCommand` strings (e.g. `pax -rf ${curlPax}`).
 * Pax files uploaded to fixed USS names (`configmgr.pax`, `zis-test.pax`, …) do not need a slot here
 * because subsequent steps use those literals, not a variable basename.
 */
type TrackedPaxBasename = 'launcherPax' | 'curlPax' | 'keyringUtilPax' | 'getEsmArchive';

type RemotePaxUploadSpec = {
  label: string;
  match: RegExp;
  /** If set, basename is stored for later uss.runCommand steps */
  trackAs?: TrackedPaxBasename;
  /** Skip this row when false (e.g. optional tooling downloads). */
  when?: () => boolean;
  /**
   * USS directory for the upload. Default `ussWorkDir`; use `binUtils` when the zwe tarball
   * must exist first (e.g. certificate-analyser.jar).
   */
  uploadRoot?: 'ussWorkDir' | 'binUtils';
} & ({ remoteName: string; useSourceBasename?: false } | { useSourceBasename: true });

const REMOTE_SETUP_DOWNLOADS: DownloadSpec[] = [
  { kind: 'manifest', name: 'org.zowe.configmgr', when: () => DOWNLOAD_CONFIGMGR },
  { kind: 'manifest', name: 'org.zowe.configmgr-rexx', when: () => DOWNLOAD_CONFIGMGR },
  { kind: 'manifest', name: 'org.zowe.launcher', when: () => DOWNLOAD_SZWESAMP },
  { kind: 'manifest', name: 'org.zowe.zss', when: () => DOWNLOAD_SZWESAMP },
  { kind: 'manifest', name: 'org.zowe.keyring-utilities', when: () => DOWNLOAD_ZOWE_TOOLS },
  { kind: 'manifest', name: 'org.zopencommunity.curl', when: () => DOWNLOAD_ZOWE_TOOLS },
  { kind: 'manifest', name: 'org.zowe.getesm', when: () => DOWNLOAD_ZOWE_TOOLS },
  {
    kind: 'artifact',
    repo: 'libs-snapshot-local',
    artifactPath: 'org/zowe/vtl-cli/zowe-cli-package/1.0.7-SNAPSHOT',
    artifactName: 'vtl.tar.gz',
    when: () => DOWNLOAD_ZOWE_TOOLS,
  },
  { kind: 'manifest', name: 'org.zowe.zis-test', when: () => DOWNLOAD_ZOWE_TOOLS },
  { kind: 'manifest', name: 'org.zowe.bind-test', when: () => DOWNLOAD_ZOWE_TOOLS },
  { kind: 'manifest', name: 'org.zowe.apiml.sdk.certificate-analyser', when: () => DOWNLOAD_ZOWE_TOOLS },
  { kind: 'manifest', name: 'org.zowe.zowe-native-proto', when: () => DOWNLOAD_ZOWE_TOOLS },
];

/** Pax/tar members uploaded to ussWorkDir before zwe build. */
const REMOTE_PAX_UPLOADS_BEFORE_ZWE: RemotePaxUploadSpec[] = [
  { label: 'configmgr pax', match: /configmgr.*\.pax/, remoteName: 'configmgr.pax' },
  { label: 'configmgr-rexx pax', match: /configmgr-rexx.*\.pax/, remoteName: 'configmgr-rexx.pax' },
  { label: 'zss pax', match: /zss-.*\.pax/, remoteName: 'zss.pax' },
  { label: 'launcher pax', match: /launcher.*\.pax/, useSourceBasename: true, trackAs: 'launcherPax' },
  { label: 'curl pax', match: /curl.*\.pax.Z/, useSourceBasename: true, trackAs: 'curlPax' },
  { label: 'keyring-utilities pax', match: /keyring-util.*\.pax/, useSourceBasename: true, trackAs: 'keyringUtilPax' },
  { label: 'zowex archive', match: /zowe-server.*pax.Z/, remoteName: 'zowex.pax.Z' },
  { label: 'zis-test pax', match: /zis-test.*\.pax/, remoteName: 'zis-test.pax' },
  { label: 'bind-test pax', match: /bind-test.*\.pax/, remoteName: 'bind-test.pax' },
];

/** Uploads after zwe tarball extract (bin/utils exists). Same spec model as REMOTE_PAX_UPLOADS_BEFORE_ZWE. */
const REMOTE_PAX_UPLOAD_AFTER_ZWE: RemotePaxUploadSpec[] = [
  {
    label: 'certificate-analyser jar',
    match: /certificate-analyser.*\.jar/,
    remoteName: 'certificate-analyser.jar',
    uploadRoot: 'binUtils',
  },
  { label: 'getesm pax', match: /getesm.*\.pax/, useSourceBasename: true, trackAs: 'getEsmArchive' },
];

function findDownloadedFile(downloadsDirPath: string, pattern: RegExp, what: string): string {
  const names = fs.readdirSync(downloadsDirPath);
  const found = names.find((item) => pattern.test(item));
  if (found == null) {
    throw new Error(`Could not locate ${what} in downloads directory`);
  }
  return found;
}

type RemotePaxUploadContext = { downloadsDirPath: string; ussWorkDir: string; binUtils: string };

/** Resolve, upload, and optionally record basenames for later pax/uss commands. */
async function uploadRemotePaxSpecs(
  specs: RemotePaxUploadSpec[],
  ctx: RemotePaxUploadContext,
  tracked: Partial<Record<TrackedPaxBasename, string>>,
): Promise<void> {
  for (const spec of specs) {
    if (spec.when != null && !spec.when()) {
      continue;
    }
    const base = findDownloadedFile(ctx.downloadsDirPath, spec.match, spec.label);
    if (spec.trackAs != null) {
      tracked[spec.trackAs] = base;
    }
    const uploadRoot = spec.uploadRoot === 'binUtils' ? ctx.binUtils : ctx.ussWorkDir;
    const localPath = path.resolve(ctx.downloadsDirPath, base);
    let remoteUssPath: string;
    if ('useSourceBasename' in spec && spec.useSourceBasename === true) {
      remoteUssPath = path.join(uploadRoot, base);
    } else {
      remoteUssPath = path.join(uploadRoot, spec.remoteName);
    }
    await uploadFileToUss(localPath, remoteUssPath, { binary: true });
  }
}

async function uploadFileToUss(localPath: string, remoteUssPath: string, options: { binary: boolean }): Promise<void> {
  console.log(`Uploading ${localPath} to ${remoteUssPath}...`);
  await files.Upload.fileToUssFile(zosmfSession, localPath, remoteUssPath, { binary: options.binary });
}

/** Extract pax in ussWorkDir, copy a file or glob into bin/utils; optional chmod +x on a path under bin/utils. */
async function paxUnpackCopyToBinUtils(
  ussWorkDir: string,
  binUtils: string,
  paxRef: string,
  copySpec: string,
  chmodRelative?: string,
): Promise<void> {
  const chmod = chmodRelative != null ? ` && chmod +x ${binUtils}/${chmodRelative}` : '';
  await uss.runCommand(`pax -ppx -rf ${paxRef} && cp -f ${copySpec} ${binUtils}${chmod}`, ussWorkDir);
}

module.exports = async () => {
  const ussRoot = REMOTE_SYSTEM_INFO.ussTestDir;
  const ussWorkDir = `${ussRoot}/.setup`;
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
    const binUtils = `${ussRoot}/bin/utils`;
    // we're downloading everything, so take the opportunity to clean up old files
    if (DOWNLOAD_CONFIGMGR && DOWNLOAD_SZWESAMP && DOWNLOAD_ZOWE_TOOLS) {
      fs.rmSync(downloadsDir, { force: true, recursive: true });
      fs.mkdirSync(downloadsDir);
    }
    for (const spec of REMOTE_SETUP_DOWNLOADS) {
      if (spec.when != null && !spec.when()) {
        continue;
      }
      if (spec.kind === 'manifest') {
        await downloadManifestDep(spec.name);
      } else {
        await downloadArtifact(spec.repo, spec.artifactPath, spec.artifactName);
      }
    }

    const vtlArchive = findDownloadedFile(downloadsDir, /vtl\.tar\.gz/, 'vtl tar');

    console.log(`Setting up remote server on ${REMOTE_SYSTEM_INFO.hostname}...`);
    await uss.runCommand(`rm -rf ${ussRoot} && mkdir -p ${ussRoot} && mkdir -p ${ussWorkDir}`);

    // zowe-install-packaging-tools and vtl-cli
    const utilsDir = path.resolve(buildDir, 'utils');
    fs.mkdirpSync(`${utilsDir}`);

    console.log(`Repacking vtl-cli....`);
    tar.x({ f: path.resolve(downloadsDir, vtlArchive), C: utilsDir, sync: true }, []);
    const finalVtlPkg = path.resolve(utilsDir, 'vtl-cli.tar');
    // Re-pack without compression which can cause issues on backend
    tar.c({ gzip: false, file: finalVtlPkg, cwd: utilsDir, sync: true }, ['vtl', 'vtl-cli.jar', 'zos']);
    await uploadFileToUss(finalVtlPkg, `${ussWorkDir}/${path.basename(finalVtlPkg)}`, { binary: true });

    const paxUploadCtx: RemotePaxUploadContext = { downloadsDirPath: downloadsDir, ussWorkDir, binUtils };
    const trackedBasenames: Partial<Record<TrackedPaxBasename, string>> = {};
    await uploadRemotePaxSpecs(REMOTE_PAX_UPLOADS_BEFORE_ZWE, paxUploadCtx, trackedBasenames);

    const launcherPax = trackedBasenames.launcherPax;
    const curlPax = trackedBasenames.curlPax;
    const keyringUtilPax = trackedBasenames.keyringUtilPax;
    if (launcherPax == null || curlPax == null || keyringUtilPax == null) {
      throw new Error('Internal error: expected launcher, curl, and keyring pax basenames after upload loop');
    }

    console.log(`Building zwe typescript...`);
    execSync(`npm install && npm run prod`, { cwd: zweBuildPath });

    await cleanUssDir(`${ussRoot}/bin`);
    await cleanUssDir(`${ussRoot}/schemas`);

    console.log(`Uploading ${REPO_ROOT_DIR}/bin to ${ussRoot}/bin...`);

    // archive without compression (issues on some backends)
    const tarFile = path.resolve(buildDir, 'zwe.tar');
    fs.cpSync(path.resolve(REPO_ROOT_DIR, 'bin'), path.resolve(buildDir, 'bin'), { force: true, recursive: true });
    console.log('Converting bin to ebcdic locally, then uploading and unpacking...');
    convertDirToEbcdicInPlace(path.resolve(buildDir, 'bin'));
    tar.c({ gzip: false, file: tarFile, sync: true, cwd: buildDir }, ['bin']);
    await uploadFileToUss(tarFile, `${ussWorkDir}/zwe.tar`, { binary: true });
    await uss.runCommand(`tar -xfo ${ussWorkDir}/zwe.tar`, ussRoot);

    await uss.runCommand(`chmod 755 ${ussRoot}/bin/zwe ${binUtils}/opercmd.rex ${binUtils}/getSDSF.rex`, ussRoot);

    const trackedAfterZwe: Partial<Record<TrackedPaxBasename, string>> = {};
    await uploadRemotePaxSpecs(REMOTE_PAX_UPLOAD_AFTER_ZWE, paxUploadCtx, trackedAfterZwe);
    const getEsmArchive = trackedAfterZwe.getEsmArchive;
    if (getEsmArchive == null) {
      throw new Error('Internal error: expected getesm pax basename after post-zwe upload loop');
    }
    await paxUnpackCopyToBinUtils(ussWorkDir, binUtils, getEsmArchive, 'getesm');

    console.log(`Unpacking ${curlPax} and moving curl to ${binUtils}...`);
    await paxUnpackCopyToBinUtils(ussWorkDir, binUtils, curlPax, 'curl-*/bin/curl');

    console.debug(`Unpacking zis-test.pax and moving zis-test to ${binUtils}...`);
    await paxUnpackCopyToBinUtils(ussWorkDir, binUtils, 'zis-test.pax', 'zis-test', 'zis-test');

    console.debug(`Unpacking bind-test.pax and moving bind-test to ${binUtils}...`);
    await paxUnpackCopyToBinUtils(ussWorkDir, binUtils, 'bind-test.pax', 'bind-test', 'bind-test');

    console.log(`Unpacking ${keyringUtilPax} and moving keyring-util to ${binUtils}...`);
    await paxUnpackCopyToBinUtils(ussWorkDir, binUtils, keyringUtilPax, 'keyring-util');

    console.log(`Uploading ${REPO_ROOT_DIR}/schemas to ${ussRoot}/schemas...`);
    await files.Upload.dirToUSSDirRecursive(zosmfSession, path.resolve(REPO_ROOT_DIR, 'schemas'), `${ussRoot}/schemas/`, {
      binary: false,
      includeHidden: true,
    });

    console.log(`Uploading ${REPO_ROOT_DIR}/files/defaults.yaml to ${ussRoot}...`);
    await uss.runCommand(`mkdir -p ${ussRoot}/files`);
    await uploadFileToUss(path.resolve(REPO_ROOT_DIR, 'files', 'defaults.yaml'), `${ussRoot}/files/defaults.yaml`, {
      binary: false,
    });

    console.log(`Uploading ${REPO_ROOT_DIR}/files/SZWESAMP and ${REPO_ROOT_DIR}/files/SZWEEXEC to ${ussRoot}...`);
    for (const sub of ['SZWESAMP', 'SZWEEXEC'] as const) {
      await files.Upload.dirToUSSDir(zosmfSession, path.resolve(REPO_ROOT_DIR, 'files', sub), `${ussRoot}/files/${sub}`, {
        binary: false,
      });
    }

    console.log(`Uploading ${REPO_ROOT_DIR}/workflows/templates/ZWESECUR.vtl and ZWESECUR.properties to ${ussWorkDir}...`);
    for (const name of ['ZWESECUR.vtl', 'ZWESECUR.properties'] as const) {
      await uploadFileToUss(path.resolve(REPO_ROOT_DIR, 'workflows', 'templates', name), `${ussWorkDir}/${name}`, {
        binary: false,
      });
    }

    const pdsSetups: Array<[string, typeof SIMPLE_PDS_PARAMS] | [string, typeof LOADLIB_PARAMS]> = [
      [REMOTE_SYSTEM_INFO.szweexec, SIMPLE_PDS_PARAMS],
      [REMOTE_SYSTEM_INFO.szwesamp, SIMPLE_PDS_PARAMS],
      [REMOTE_SYSTEM_INFO.szweload, LOADLIB_PARAMS],
      [REMOTE_SYSTEM_INFO.proclib, SIMPLE_PDS_PARAMS],
      [REMOTE_SYSTEM_INFO.parmlib, SIMPLE_PDS_PARAMS],
      [REMOTE_SYSTEM_INFO.authLoadLib, LOADLIB_PARAMS],
      [REMOTE_SYSTEM_INFO.authPluginLib, LOADLIB_PARAMS],
    ];
    for (const [dsn, params] of pdsSetups) {
      await createPds(dsn, params);
    }

    console.log(`Unpacking configmgr and placing it in bin/utils ...`);
    await uss.runCommand(`pax -ppx -rf configmgr.pax && mv configmgr ${binUtils}/`, ussWorkDir);

    console.log(`Unpacking configmgr-rexx and placing it in ${REMOTE_SYSTEM_INFO.szweload} ...`);
    await uss.runCommand(`pax -ppx -rf configmgr-rexx.pax`, ussWorkDir);
    await uss.runCommand(`mkdir -p ${ussRoot}/files/SZWELOAD`);
    for (const pgm of ['ZWERXCFG', 'ZWECFG31', 'ZWECFG64']) {
      await uss.runCommand(`cp -X ${pgm} "//'${REMOTE_SYSTEM_INFO.szweload}(${pgm})'"`, ussWorkDir);
      await uss.runCommand(`cp ${pgm} ${ussRoot}/files/SZWELOAD`, ussWorkDir);
    }

    console.log(`Unpacking zowex pax and placing zowex in utils directory ... `);
    await uss.runCommand(`pax -ppx -rf zowex.pax.Z`, ussWorkDir);
    await uss.runCommand(`cp -f ${ussWorkDir}/zowex ${binUtils}`);

    console.log(`Unpacking zss pax and placing SAMPLIB in ${REMOTE_SYSTEM_INFO.szwesamp} ...`);
    await uss.runCommand(`mkdir -p ${ussRoot}/components/zss`);
    await uss.runCommand(`cp zss.pax ${ussRoot}/components/zss`, ussWorkDir);
    await uss.runCommand(`pax -ppx -rf zss.pax`, `${ussRoot}/components/zss`);
    await uss.runCommand(`rm zss.pax`, `${ussRoot}/components/zss`);
    const zssPgms = [
      { from: 'ZWESIP00', to: 'ZWESIP00' },
      { from: 'ZWESISCH', to: 'ZWESISCH' },
      { from: 'ZWESASTC', to: 'ZWESASTC' },
      { from: 'ZWESISTC', to: 'ZWESISTC' },
    ];
    for (const pgm of zssPgms) {
      const resp = await uss.runCommand(
        `cp SAMPLIB/${pgm.from} "//'${REMOTE_SYSTEM_INFO.szwesamp}(${pgm.to})'"`,
        `${ussRoot}/components/zss`,
      );
      if (resp.rc !== 0) {
        throw new Error(`Failed to copy ${pgm.from} to ${pgm.to}`);
      }
    }

    console.log(`Unpacking launcher pax and placing SAMPLIB in ${REMOTE_SYSTEM_INFO.szwesamp} ...`);
    await uss.runCommand(`mkdir -p ${ussRoot}/components/launcher`);
    await uss.runCommand(`cp ${launcherPax} ${ussRoot}/components/launcher`, ussWorkDir);
    await uss.runCommand(`pax -ppx -rf ${launcherPax}`, `${ussRoot}/components/launcher`);
    await uss.runCommand(`rm ${launcherPax}`, `${ussRoot}/components/launcher`);
    for (const pgm of ['ZWESLSTC']) {
      await uss.runCommand(`cp samplib/${pgm} "//'${REMOTE_SYSTEM_INFO.szwesamp}(${pgm})'"`, `${ussRoot}/components/launcher`);
    }
    console.log(`Unpacking vtl-cli, generating ZWESECUR, and copying it to SZWESAMP`);
    await uss.runCommand(`tar -xf vtl-cli.tar && rm -rf vtl-cli && mkdir -p vtl-cli && mv vtl vtl-cli.jar zos vtl-cli`, ussWorkDir);
    await uss.runCommand(
      `${REMOTE_SYSTEM_INFO.zosJavaHome}/bin/java -jar ${ussWorkDir}/vtl-cli/vtl-cli.jar -ie Cp1140 --yaml-context ZWESECUR.properties ZWESECUR.vtl -oe Cp1140 > ZWESECUR.jcl`,
      ussWorkDir,
    );
    await uss.runCommand(`cp ${ussWorkDir}/ZWESECUR.jcl "//'${REMOTE_SYSTEM_INFO.szwesamp}(ZWESECUR)'"`);

    console.log(`Compiling Java utilities in bin/utils using ${REMOTE_SYSTEM_INFO.zosJavaHome}...`);
    await uss.runCommand(`${REMOTE_SYSTEM_INFO.zosJavaHome}/bin/javac *.java`, binUtils);

    const pdsUploads: Array<[string, string]> = [
      ['SZWESAMP', REMOTE_SYSTEM_INFO.szwesamp],
      ['SZWEEXEC', REMOTE_SYSTEM_INFO.szweexec],
    ];
    for (const [sub, dsn] of pdsUploads) {
      console.log(`Uploading JCL from files/${sub} to ${dsn}...`);
      await files.Upload.dirToPds(zosmfSession, path.resolve(REPO_ROOT_DIR, 'files', sub), dsn, { binary: false });
    }

    await uploadFileToUss(path.resolve(REPO_ROOT_DIR, 'manifest.json.template'), `${ussRoot}/manifest.json`, {
      binary: false,
    });

    console.log('Remote server setup complete');
  }
};
