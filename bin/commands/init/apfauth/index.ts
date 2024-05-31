/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as zosJes from '../../../libs/zos-jes';
import * as zosDs  from '../../../libs/zos-dataset';
import * as zoslib from '../../../libs/zos';
import * as common from '../../../libs/common';
import * as config from '../../../libs/config';
import * as fs     from '../../../libs/fs';
import * as shell  from '../../../libs/shell';
import * as stringlib from '../../../libs/string';
import * as xplatform from 'xplatform';

export function execute() {

  common.printLevel1Message(`APF authorize load libraries`);

  // Validation
  common.requireZoweYaml();
  const ZOWE_CONFIG = config.getZoweConfig();

  // read prefix and validate
  const prefix=ZOWE_CONFIG.zowe?.setup?.dataset?.prefix;
  if (!prefix) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }

  // read JCL library and validate
  const jcllib = zoslib.verifyGeneratedJcl(ZOWE_CONFIG);
  if (!jcllib) {
    return common.printErrorAndExit(`Error ZWEL0319E: zowe.setup.dataset.jcllib does not exist, cannot run. Run 'zwe init', 'zwe init generate', or submit JCL ${prefix}.SZWESAMP(ZWEGENER) before running this command.`, undefined, 319);
  }

  
  ['authLoadlib', 'authPluginLib'].forEach((key)=> {
    if (!ZOWE_CONFIG.zowe?.setup?.dataset || !ZOWE_CONFIG.zowe?.setup?.dataset[key]) {
      common.printErrorAndExit(`Error ZWEL0157E: zowe.setup.dataset.${key} is not defined in Zowe YAML configuration file.`, undefined, 157);
    }
  });

  let result1 = zosDs.isDatasetSmsManaged(ZOWE_CONFIG.zowe.setup.dataset.authLoadlib);
  let result2 = zosDs.isDatasetSmsManaged(ZOWE_CONFIG.zowe.setup.dataset.authPluginLib);
  if (!result1.smsManaged || !result2.smsManaged) {
    const COMMAND_LIST = std.getenv('ZWE_CLI_COMMANDS_LIST');
    const tmpfile = fs.createTmpFile(`zwe ${COMMAND_LIST}`.replace(new RegExp('\ ', 'g'), '-'));
    common.printDebug(`- Copy ${jcllib}(ZWEIAPF2) to ${tmpfile}`);
    let jclContent = shell.execOutSync('sh', '-c', `cat "//'${stringlib.escapeDollar(jcllib)}(ZWEIAPF2)'" 2>&1`);
    if (jclContent.out && jclContent.rc == 0) {
      common.printDebug(`  * Succeeded`);
      common.printTrace(`  * Output:`);
      common.printTrace(stringlib.paddingLeft(jclContent.out, "    "));
      
      if (!result1.smsManaged) {
        let result3 = zosDs.getDatasetVolume(ZOWE_CONFIG.zowe.setup.dataset.authLoadlib);
        jclContent.out = jclContent.out.replace("export LOADLOC=SMS", `export LOADLOC="VOLUME=${result3.volume}"`);
      }
      if (!result2.smsManaged) {
        let result4 = zosDs.getDatasetVolume(ZOWE_CONFIG.zowe.setup.dataset.authPluginLib);
        jclContent.out = jclContent.out.replace("export PLUGLOC=SMS", `export PLUGLOC="VOLUME=${result4.volume}"`);
      }

      xplatform.storeFileUTF8(tmpfile, xplatform.AUTO_DETECT, jclContent.out);
      common.printTrace(`  * Stored:`);
      common.printTrace(stringlib.paddingLeft(jclContent.out, "    "));

      shell.execSync('chmod', '700', tmpfile);
      if (!fs.fileExists(tmpfile)) {
        common.printErrorAndExit(`Error ZWEL0159E: Failed to prepare ZWEIAPF2`, undefined, 159);
      }
      
      zosJes.printAndHandleJcl(tmpfile, `ZWEIAPF2`, jcllib, prefix, true);
    } else {
      common.printDebug(`  * Failed`);
      common.printError(`  * Exit code: ${jclContent.rc}`);
      common.printError(`  * Output:`);
      if (jclContent.out) {
        common.printError(stringlib.paddingLeft(jclContent.out, "    "));
      }
      std.exit(1);
    }
  } else {
    zosJes.printAndHandleJcl(`//'${jcllib}(ZWEIAPF2)'`, `ZWEIAPF2`, jcllib, prefix);      
  }
  common.printLevel2Message(`Zowe load libraries are APF authorized successfully.`);
}
