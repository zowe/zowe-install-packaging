/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/


import * as std from 'cm_std';
import * as zos from 'zos';
import * as xplatform from 'xplatform';

import * as fs from '../../../libs/fs';
import * as common from '../../../libs/common';
import * as stringlib from '../../../libs/string';
import * as shell from '../../../libs/shell';
import * as config from '../../../libs/config';
import * as zoslib from '../../../libs/zos';
import * as zosJes from '../../../libs/zos-jes';
import * as zosdataset from '../../../libs/zos-dataset';


export function execute(allowOverwrite: boolean = false) {

  common.printLevel1Message(`Install Zowe main started task`);
  
  // constants
  const COMMAND_LIST = std.getenv('ZWE_CLI_COMMANDS_LIST');
  
  let stcExistence: boolean;
  
  // validation
  common.requireZoweYaml();
  const ZOWE_CONFIG=config.getZoweConfig();
  
  // read prefix and validate
  const prefix=ZOWE_CONFIG.zowe?.setup?.dataset?.prefix;
  if (!prefix) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }
  // read PROCLIB and validate
  const proclib=ZOWE_CONFIG.zowe.setup?.dataset?.proclib;
  if (!proclib) {
    common.printErrorAndExit(`Error ZWEL0157E: PROCLIB (zowe.setup.dataset.proclib) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }
  // read JCL library and validate
  const jcllib = zoslib.verifyGeneratedJcl(ZOWE_CONFIG);
  if (!jcllib) {
    return common.printErrorAndExit(`Error ZWEL0319E: zowe.setup.dataset.jcllib does not exist, cannot run. Run 'zwe init', 'zwe init generate', or submit JCL ${prefix}.SZWESAMP(ZWEGENER) before running this command.`, undefined, 319);
  }

  let security_stcs_zowe=ZOWE_CONFIG.zowe.setup?.security?.stcs?.zowe;
  if (!security_stcs_zowe) {
    common.printErrorAndExit(`Error ZWEL0157E: (zowe.setup.security.stcs.zowe) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }
  let security_stcs_zis=ZOWE_CONFIG.zowe.setup?.security?.stcs?.zis;
  if (!security_stcs_zis) {
    common.printErrorAndExit(`Error ZWEL0157E: (zowe.setup.security.stcs.zis) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }
  let security_stcsAux=ZOWE_CONFIG.zowe.setup?.security?.stcs?.aux;
  if (!security_stcsAux) {
    common.printErrorAndExit(`Error ZWEL0157E: (zowe.setup.security.stcs.aux) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }

  [security_stcs_zowe, security_stcs_zis, security_stcsAux].forEach((mb: string) => {
    // STCs in target proclib
    if (zosdataset.isDatasetExists(`${proclib}(${mb})`)) {
      stcExistence = true;
      if (allowOverwrite) {
        // warning
        common.printMessage(`Warning ZWEL0300W: ${proclib}(${mb}) already exists. This data set member will be overwritten during configuration.`);
      } else {
        // warning
        common.printMessage(`Warning ZWEL0301W: ${proclib}(${mb}) already exists and will not be overwritten. For upgrades, you must use --allow-overwrite.`);
      }
    }
  });

  if (stcExistence == true && !allowOverwrite) {
    common.printMessage(`Skipped writing to ${proclib}. To write, you must use --allow-overwrite.`);
  } else {
    // Fix JCL if needed - cannot copy member with same name via (foo,foo,R)
    //                     must instead be (foo,,R), so do string replace if see dual name.
    if (stcExistence == true) {
      zosJes.printAndHandleJcl(`//'${jcllib}(ZWERSTC)'`, `ZWERSTC`, jcllib, prefix, false, true);
    }
    
    const tmpfile = fs.createTmpFile(`zwe ${COMMAND_LIST}`.replace(new RegExp('\ ', 'g'), '-'));
    common.printDebug(`- Copy ${jcllib}(ZWEISTC) to ${tmpfile}`);
    const jclContent = shell.execOutSync('sh', '-c', `cat "//'${stringlib.escapeDollar(jcllib)}(ZWEISTC)'" 2>&1`);
    if (jclContent.out && jclContent.rc == 0) {
      common.printDebug(`  * Succeeded`);
      common.printTrace(`  * Output:`);
      common.printTrace(stringlib.paddingLeft(jclContent.out, "    "));

      const tmpFileContent = jclContent.out.replace("ZWESLSTC,ZWESLSTC", "ZWESLSTC,")
                                           .replace("ZWESISTC,ZWESISTC", "ZWESISTC,")
                                           .replace("ZWESASTC,ZWESASTC", "ZWESASTC,");
      xplatform.storeFileUTF8(tmpfile, xplatform.AUTO_DETECT, tmpFileContent);
      common.printTrace(`  * Stored:`);
      common.printTrace(stringlib.paddingLeft(tmpFileContent, "    "));

      shell.execSync('chmod', '700', tmpfile);
    } else {
      common.printDebug(`  * Failed`);
      common.printError(`  * Exit code: ${jclContent.rc}`);
      common.printError(`  * Output:`);
      if (jclContent.out) {
        common.printError(stringlib.paddingLeft(jclContent.out, "    "));
      }
      std.exit(1);
    }
    if (!fs.fileExists(tmpfile)) {
      common.printErrorAndExit(`Error ZWEL0159E: Failed to modify ZWEISTC`, undefined, 159);
    }
    
    zosJes.printAndHandleJcl(tmpfile, `ZWEISTC`, jcllib, prefix, true);
    common.printLevel2Message(`Zowe main started tasks are installed successfully.`);
  }
}
