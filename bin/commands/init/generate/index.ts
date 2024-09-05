/*
// This program and the accompanying materials are made available
// under the terms of the Eclipse Public License v2.0 which
// accompanies this distribution, and is available at
// https://www.eclipse.org/legal/epl-v20.html
//
// SPDX-License-Identifier: EPL-2.0
//
// Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as os from "cm_os";
import * as xplatform from "xplatform";
import * as fs from '../../../libs/fs';
import * as config from '../../../libs/config';
import * as common from '../../../libs/common';
import * as shell from '../../../libs/shell';
import * as stringlib from '../../../libs/string';
import * as zosDataset from '../../../libs/zos-dataset';
import * as zosFs from '../../../libs/zos-fs';
import * as zosJes from '../../../libs/zos-jes';

export function execute(dryRun?: boolean) {
  common.requireZoweYaml();
  const ZOWE_CONFIG=config.getZoweConfig();

  const prefix=ZOWE_CONFIG.zowe.setup?.dataset?.prefix;
  if (!prefix) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }

  const runtimeDirectory=ZOWE_CONFIG.zowe.runtimeDirectory;
  if (!runtimeDirectory) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe runtime directory (zowe.runtimeDirectory) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }
  
  let jclPostProcessing = false;
  let jclHeaderJoined = '';
  const jclHeader = ZOWE_CONFIG.zowe.environments.jclHeader;
  if (Array.isArray(jclHeader)) {
    jclPostProcessing = true;
    jclHeaderJoined = jclHeader.join("\n");
  } else {
    jclHeaderJoined = jclHeader.toString();
    if (jclHeaderJoined && (jclHeaderJoined.match(/\n/g) || []).length) {
      jclPostProcessing = true;
    }
  }

  const tempFile = fs.createTmpFile();
  if (zosFs.copyMvsToUss(ZOWE_CONFIG.zowe.setup.dataset.prefix + '.SZWESAMP(ZWEGENER)', tempFile) !== 0) {
    common.printErrorAndExit(`ZWEL0143E Cannot find data set member '${ZOWE_CONFIG.zowe.setup.dataset.prefix + '.SZWESAMP(ZWEGENER)'}'. You may need to re-run zwe install.`, undefined, 143);
  }
  let jclContents = xplatform.loadFileUTF8(tempFile, xplatform.AUTO_DETECT);

  // Replace is using special replacement patterns, by doubling '$' we will avoid that
  // Otherwise: let d4 = '$$$$'; console.log('a'.replace(/a/gi, d4)); --> '$$' (we want '$$$$')
  // $$ inserts a '$', replace(/[$]/g, '$$$$') => double each '$' occurence
  jclContents = jclContents.replace(/\{zowe\.setup\.dataset\.prefix\}/gi, prefix.replace(/[$]/g, '$$$$'));
  jclContents = jclContents.replace(/\{zowe\.runtimeDirectory\}/gi, runtimeDirectory.replace(/[$]/g, '$$$$'));
  jclContents = jclContents.replace(/\{zowe\.environments\.jclHeader\}/i,jclHeaderJoined.replace(/[$]/g, '$$$$'));
  if (std.getenv('ZWE_PRIVATE_LOG_LEVEL_ZWELS') !== 'INFO') {
    jclContents = jclContents.replace('noverbose -', 'verbose -');
  }
  let originalConfig = std.getenv('ZWE_PRIVATE_CONFIG_ORIG');
  let startingConfig = originalConfig;
  if ((originalConfig.indexOf('FILE(') == -1) && (originalConfig.indexOf('PARMLIB(') == -1)) {
    startingConfig = 'FILE('+originalConfig+')';
  }

  let parts = startingConfig.split(/(FILE\(|PARMLIB\()/g).filter(item => item.length > 0);
  let configLines = [];
  let state = '';

  for (let i = 0; i < parts.length; i++) {
    let part = parts[i];
    if (part == 'FILE(') {
      state = part;
    } else if (part == 'PARMLIB(') {
      state = part;
    } else if (state == 'FILE(') {
      let filename = part.substring(0, part.indexOf(')'));
      configLines.push('FILE ' + fs.convertToAbsolutePath(filename).replace(/[$]/g, '$$$$'));
      state = null;
    } else if (state == 'PARMLIB(') {
      let memberIndex = part.indexOf('(');
      if (memberIndex != -1) {
        let endIndex = part.indexOf(')', memberIndex);
        let member = part.substring(memberIndex+1, endIndex);
        if (member.toUpperCase() != 'ZWEYAML') {
          common.printErrorAndExit(`ZWEL0319E Configuration stored in PARMLIB must use member name ZWEYAML when using generate action.`, undefined, 319);
        }
      }
      configLines.push('PARMLIB ' + part.substring(0, part.indexOf('(')).replace(/[$]/g, '$$$$'));
      state = null;
    }
  }

  jclContents = jclContents.replace('FILE <full path to zowe.yaml file>', configLines.join('\n'));

  xplatform.storeFileUTF8(tempFile, xplatform.AUTO_DETECT, jclContents);
  
  common.printMessage(`Template JCL: ${ZOWE_CONFIG.zowe.setup.dataset.prefix + '.SZWESAMP(ZWEGENER)'}`);
  common.printMessage('--- JCL content ---');
  common.printMessage(jclContents);
  common.printMessage('--- End of JCL ---');
  
  if (dryRun) {
    common.printMessage('JCL not submitted, command run with "--dry-run" flag.');
    common.printMessage('To perform command, re-run command without "--dry-run" flag, or submit the JCL directly.');
    os.remove(tempFile);

  } else { //TODO can we generate just for one step, or no reason?    
    common.printMessage('Submitting Job ZWEGENER');
    const jobid = zosJes.submitJob(tempFile);
    const result = zosJes.waitForJob(jobid);
    if (!jclPostProcessing) {
      os.remove(tempFile);
    }
    common.printMessage(`Job completed with RC=${result.rc}`);
    if (result.rc == 0) {
      if (jclPostProcessing) {
        const memList = zosDataset.listDatasetMembers(ZOWE_CONFIG.zowe.setup.dataset.jcllib);
        if (memList.length) {
          common.printDebug(`  - Adding "${jclHeaderJoined}" to:`);
          for (let m = 0; m < memList.length; m++) {
            let catResult = shell.execOutSync('sh', '-c', `cat "//'${stringlib.escapeDollar(ZOWE_CONFIG.zowe.setup.dataset.jcllib)}(${memList[m]})'"`);
            if (catResult.rc == 0 && catResult.out) {
              jclContents = null;
              if (memList[m] == 'ZWESECUR') {
                jclContents = catResult.out.replace(/^\/\/ZWESECUR JOB/i, '//ZWESECUR JOB ' + jclHeaderJoined.replace(/[$]/g, '$$$$'));
              } else {
                if (catResult.out.match(/\{zowe\.environments\.jclHeader\}/i)) {
                  jclContents = catResult.out.replace(/\{zowe\.environments\.jclHeader\}/i, jclHeaderJoined.replace(/[$]/g, '$$$$'));
                }
              }
              if (jclContents) {
                xplatform.storeFileUTF8(tempFile, xplatform.AUTO_DETECT, jclContents);
                shell.execSync('sh', '-c', `cp "${tempFile}" "//'${stringlib.escapeDollar(ZOWE_CONFIG.zowe.setup.dataset.jcllib)}(${memList[m]})'"`);
                common.printDebug(`    - ${ZOWE_CONFIG.zowe.setup.dataset.jcllib}(${memList[m]})`);
              }
            }
          }
        }
        os.remove(tempFile);
    }
    common.printMessage("Zowe JCL generated successfully");
    } else {
      common.printMessage(`Zowe JCL generated with errors, check job log. Job completion code=${result.jobcccode}, Job completion text=${result.jobcctext}`);
    }
    // print if succesful
  }
}
