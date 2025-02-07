/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html

  SPDX-License-Identifier: EPL-2.0

  Copyright Contributors to the Zowe Project.
*/

// TODO: job log
// To avoid of using SDSF, we used to use TSO output command to export job log
// but it always fails with below error for me:
//   IKJ56328I JOB ZWE1SV REJECTED - JOBNAME MUST BE YOUR USERID OR MUST START WITH YOUR USERID
// REF: https://www.ibm.com/docs/en/zos/2.3.0?topic=subcommands-output-command
// REF: https://www.ibm.com/docs/en/zos/2.3.0?topic=ikj-ikj56328i

import * as std from 'cm_std';
import * as zos from 'zos';
import * as xplatform from 'xplatform'

import * as common from '../../libs/common';
import * as component from '../../libs/component';
import * as config from '../../libs/config';
import * as fs from '../../libs/fs';
import * as java from '../../libs/java';
import * as javaCI from '../../libs/java_ci';
import * as node from '../../libs/node'
import * as shell from '../../libs/shell';
import * as zoslib from '../../libs/zos';
import * as zosfs from '../../libs/zos-fs';
import * as zosmf from '../../libs/zosmf';

import * as verifyFingerprints from './verify-fingerprints/index';

function zssCheck(zssBinary: string): string {
  if (fs.fileExists(zssBinary)) {
      return `${zssBinary} = ${component.hasPCBit(zssBinary)}`
  } else {
      common.printError(`Error ZWEL0150E: Failed to find file "${zssBinary}". Zowe runtimeDirectory is invalid.`);
      return `Missing file: ${zssBinary}`
  }
}

export function execute(): void {

  common.printLevel0Message('Collect information for Zowe support');
  const isoDate = new Date().toISOString().replace(/T|t|:/g,'-').substring(0,19);

  let targetDirectory = std.getenv('ZWE_CLI_PARAMETER_TARGET_DIR');
  if (targetDirectory) {
    targetDirectory = fs.convertToAbsolutePath(targetDirectory);
  } else {
    targetDirectory = fs.getTmpDir();
  }

  if (!fs.directoryExists(targetDirectory, true)) {
    common.printErrorAndExit(`Error ZWELxxxx: "${targetDirectory}" is not a valid directory.`, undefined, 999);
  }

  const tmpFilePrefix = 'zwe-support';
  const tmpPax = `${targetDirectory}/${tmpFilePrefix}.${isoDate}.pax`;
  const tmpDir = fs.createTmpFile(tmpFilePrefix, targetDirectory);

  common.requireZoweYaml();
  const ZOWE_CONFIG=config.getZoweConfig();

  common.printMessage(`Started at ${isoDate}`);
  fs.mkdirp(tmpDir, 0o700);
  common.printDebug(`Temporary directory created: ${tmpDir}`);

  common.printLevel1Message('Collecting various environment information');
  const environmentFile =`${tmpDir}/environment.json`;
  let environment = {};

  environment["zos-version"] = zoslib.formatZosVersion();

  const enabledComponents = component.getEnabledComponents();
  if (enabledComponents.includes('app-server')) {
    node.requireNode();
  }
  const nodeHome = std.getenv('NODE_HOME');
  if (nodeHome) {
    const nodeVersion = shell.execOutSync('sh', '-c', '${NODE_HOME}/bin/node -v 2>&1 | head -n 1');
    if (nodeVersion.rc == 0 && nodeVersion.out) {
      environment["node"] = `${nodeVersion.out}`;
      const discovery = ZOWE_CONFIG.components?.discovery?.enabled;
      const zosmfHost = ZOWE_CONFIG.zOSMF?.host;
      const zosmfPort = ZOWE_CONFIG.zOSMF?.port;
      if (discovery && zosmfHost && zosmfPort) {
        environment["zosmf_check"] = `'https://${zosmfHost}:${zosmfPort}/zosmf/info' => ${zosmf.validateZosmfHostAndPort(zosmfHost, zosmfPort)}`;
      }
    }
  } else {
    environment["node"] = `not found`;
  }

  java.requireJava();
  javaCI.validateJavaHome();
  const javaVersion = shell.execOutSync('sh', '-c', '${JAVA_HOME}/bin/java -version 2>&1 | head -n 1');
  if (javaVersion.rc == 0 && javaVersion.out) {
    environment["java"] = javaVersion.out.replace(/\"/g, '');
    const keytoolInfo = shell.execOutSync('sh', '-c', '${JAVA_HOME}/bin/keytool -showinfo -tls 2>&1');
    if (keytoolInfo.rc == 0 && keytoolInfo.out) {
      environment["keytool_showinfo_tls"] = keytoolInfo.out.split('\n');
    }
  }

  environment["esm"] = `${zos.getEsm()}`;

  // This command is usually failing with rc=12 and FSUM2051I/FSUM2052I messages:
  //   FSUM2051I The OMVS command failed because the display screen size is not supported.+
  //   FSUM2052I The screen size must be at least 12 by 40 but less than 10000 bytes total.  The actual primary screen size is 255 by 255 (
  //   65025 bytes).  The alternate screen size is 255 by 255 (65025 bytes).
  //   - tsoCommand will fail and print error -> we will use shell.execOutSync
  //   - We will take stdout + stderr and try to filter out messages
  const ceeOptions = shell.execOutSync('sh', '-c', `tsocmd "OMVS RUNOPTS('RPTOPTS(ON)')" 2>&1`);
  if (ceeOptions.out) {
    const ceeOptionesLines = ceeOptions.out.split('\n');
    environment["cee_runtime"] = [];
    for (let line in ceeOptionesLines) {
      if (!(/^FSUM205[1|2]I/).test(ceeOptionesLines[line]) && !(/.*the alternate screen size is.*/i).test(ceeOptionesLines[line])) {
        if (ceeOptionesLines[line].trim()) {
          environment["cee_runtime"].push(ceeOptionesLines[line]);
        }
      }
    }
  }

  const zoweRuntime = std.getenv('ZWE_zowe_runtimeDirectory');
  const fsFlags = zosfs.getFileSystemFlags(zoweRuntime);
  if (fsFlags.rc == 0) {
    environment["fs_flags"] = (({ rc, ...others }) => others)(fsFlags);  // Do not include "rc"
  }

  const zssEnabled = ZOWE_CONFIG.components?.zss?.enabled;
  if (zssEnabled) {
      const zssBinary = `${zoweRuntime}/components/zss/bin/zssServer`;
      environment["zss_program_controlled"] = {
          "31bit": `${zssCheck(zssBinary)}`,
          "64bit": `${zssCheck(`${zssBinary}64`)}`
      }
  }

  common.printMessage(JSON.stringify(environment, null, 2));
  const saveEnvRc = xplatform.storeFileUTF8(environmentFile, xplatform.AUTO_DETECT, JSON.stringify(environment, null, 2));
  if (saveEnvRc) {
    common.printErrorAndExit(`Error ZWEL0151E: Failed to create temporary file "${environmentFile}". Please check permission or volume free space.`, undefined, 151);
  }

  common.printLevel1Message('Collecting Zowe configurations');
  common.printMessage(`- manifest.json: ${zoweRuntime}/manifest.json`);
  fs.cp(`${zoweRuntime}/manifest.json`, tmpDir);

  const workspaceDirectory = ZOWE_CONFIG.zowe.workspaceDirectory;

  common.printMessage(`- configuration: ${workspaceDirectory}/.env/.zowe-merged.yaml`);

  // workspace directory must exists, otherwise the merging of configs already failed
  fs.cp(`${workspaceDirectory}/.env/.zowe-merged.yaml`, `${tmpDir}/zowe-merged.yaml`);

  common.printMessage(`- zowe.workspaceDirectory: ${workspaceDirectory}/.env`);
  fs.mkdirp(`${tmpDir}/workspace`);
  fs.cp(`${workspaceDirectory}/.env`, `${tmpDir}/workspace`)

  if (fs.directoryExists(`${workspaceDirectory}/api-mediation/api-defs`)) {
    common.printMessage(`- zowe.workspaceDirectory: ${workspaceDirectory}/api-mediation/api-defs`);
    fs.cp(`${workspaceDirectory}/api-mediation/api-defs`, `${tmpDir}/workspace/api-mediation`);
  }

  const pkcs12Directory = ZOWE_CONFIG.zowe.setup?.certificate?.pkcs12?.directory;
  if (fs.directoryExists(pkcs12Directory)) {
    common.printMessage(`- zowe.setup.certificate.pkcs12.directory: ${pkcs12Directory}`)
    fs.mkdirp(`${tmpDir}/keystore`);
    fs.cp(`${pkcs12Directory}`, `${tmpDir}/keystore`);
  }
  common.printMessage("");

  common.printLevel1Message("Collecting Zowe file fingerprints");
  const verifyFingerprintsFile = `${tmpDir}/verify-fingerprints.log`;
  const supportLogFile = std.getenv('ZWE_PRIVATE_LOG_FILE');
  const supportLogLevel = std.getenv('ZWE_PRIVATE_LOG_LEVEL_ZWELS');
  common.printMessage(`- copy original fingerprints: ${zoweRuntime}/fingerprint`);
  fs.cp(`${zoweRuntime}/fingerprint`, tmpDir);
  common.printMessage("- verify fingerprints");
  std.setenv('ZWE_PRIVATE_LOG_FILE', `${verifyFingerprintsFile}`);
  std.setenv('ZWE_PRIVATE_LOG_LEVEL_ZWELS', 'TRACE');
  fs.createFile(verifyFingerprintsFile, 0o700);
  verifyFingerprints.execute(true, std.getenv('JAVA_HOME'));
  std.setenv('ZWE_PRIVATE_LOG_FILE',`${supportLogFile}`);
  std.setenv('ZWE_PRIVATE_LOG_LEVEL_ZWELS', `${supportLogLevel}`);
  common.printMessage("");

  // zowe.job.name + prefix are in defaults
  const jobName = ZOWE_CONFIG.zowe.job.name;
  const jobPrefix = ZOWE_CONFIG.zowe.job.prefix;

  common.printLevel1Message(`Collecting current process information based on the job prefix ${jobPrefix} and job name ${jobName}`);

  const psOutputFile = `${tmpDir}/ps_output`;
  const grepCommand = `grep -i -e "^[[:space:]]*PID" -e "${jobPrefix}" -e "${jobName}"`;
  const processes = shell.execOutSync('sh', '-c', `ps -A -o pid,ppid,time,etime,user,jobname,args | ${grepCommand}`);
  //   This process has the argument, which (surprise!) is found by grep, e.g:
  //   1234   5678    00:00:00 00:00:00      ADMDIN USERID grep -i -e ^[[:space:]]*PID -e ZWE1 -e ZWE2
  if (processes.rc == 0 && processes.out) {
    let processesSplit = processes.out.split("\n");
    for (let i = 0; i < processesSplit.length; i++) {
      if (processesSplit[i].includes(grepCommand.replace(/\"/g, ''))) {
        processesSplit.splice(i, 1);
      }
    }
    if (processesSplit.length > 1) {
      common.printMessage(`- Adding ${psOutputFile}`);
      xplatform.storeFileUTF8(psOutputFile, xplatform.AUTO_DETECT, processesSplit.join("\n"));
    }
  }
  common.printMessage("");

  const logDirectory=ZOWE_CONFIG.zowe.logDirectory;  // This could be /dev/null
  if (fs.directoryExists(logDirectory, true)) {
    common.printLevel1Message(`Collecting logs from ${logDirectory}`);
    fs.mkdirp(`${tmpDir}/logs`);
    fs.cp(`${logDirectory}`, `${tmpDir}/logs`);
  }
  common.printMessage("");

  common.printLevel1Message('Create support package and clean up');
  shell.execOutSync('sh', '-c', `cd "${tmpDir}" && pax -w -v -o saveext -f "${tmpPax}" . && compress ${tmpPax} && chmod 700 "${tmpPax}.Z"`);
  fs.rmrf(tmpDir);
  common.printMessage("");

  if (fs.fileExists(`${tmpPax}.Z`)) {
    common.printLevel1Message(`Zowe support package is generated as ${tmpPax}.Z`);
  } else {
    common.printErrorAndExit(`Error ZWEL0151E: Failed to create file "${tmpPax}.Z". Please check permission or volume free space.`, undefined, 151);
  }
}
