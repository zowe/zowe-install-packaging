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
import * as zosFs from '../../../libs/zos-fs';
import * as zosJes from '../../../libs/zos-jes';

export function execute(dryRun?: boolean) {
  common.requireZoweYaml();
  const ZOWE_CONFIG=config.getZoweConfig();
  const tempFile = fs.createTmpFile();
  zosFs.copyMvsToUss(ZOWE_CONFIG.zowe.setup.dataset.prefix + '.SZWESAMP(ZWEGENER)', tempFile);
  let jclContents = xplatform.loadFileUTF8(tempFile, xplatform.AUTO_DETECT);

  jclContents = jclContents.replace("DSN={zowe.setup.dataset.prefix}", "DSN="+ZOWE_CONFIG.zowe.setup.dataset.prefix);
  jclContents = jclContents.replace("{zowe.setup.dataset.loadlib}", ZOWE_CONFIG.zowe.setup.dataset.loadlib);
  jclContents = jclContents.replace(/\{zowe\.runtimeDirectory\}/gi, ZOWE_CONFIG.zowe.runtimeDirectory);
  jclContents = jclContents.replace('FILE <full path to zowe.yaml file>', 'FILE '+ZOWE_CONFIG.zowe.workspaceDirectory+'/.env/.zowe-merged.yaml');

  xplatform.storeFileUTF8(tempFile, xplatform.AUTO_DETECT, jclContents);
  
  common.printMessage(`Template JCL: ${ZOWE_CONFIG.zowe.setup.dataset.prefix + '.SZWESAMP(ZWEGENER)'}`);
  common.printMessage('JCL content:');
  common.printMessage(jclContents);
  
  if (dryRun) {
    common.printMessage('JCL not submitted, command run with dry run flag.');
    common.printMessage('To perform command, re-run command without dry run flag, or submit the JCL directly.');
    os.remove(tempFile);

  } else { //TODO can we generate just for one step, or no reason?    
    common.printMessage('Submitting Job ZWEGENER');
    const jobid = zosJes.submitJob(tempFile);
    const result = zosJes.waitForJob(jobid);
    os.remove(tempFile);

    common.printMessage(`Job completed with RC=${result.rc}`);
    if (result.rc == 0) {
      common.printMessage("Zowe JCL generated successfully");
    } else {
      common.printMessage(`Zowe JCL generated with errors, check job log. Job completion code=${result.jobcccode}, Job completion text=${result.jobcctext}`);
    }
    // print if succesful
  }
}
