/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html

  SPDX-License-Identifier: EPL-2.0

  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as common from '../../../libs/common';
import * as config from '../../../libs/config';
import * as initGenerate from '../generate/index';
import * as zosdataset from '../../../libs/zos-dataset';
import * as zosJes from '../../../libs/zos-jes';
import * as zoslib from '../../../libs/zos';

export function execute(allowOverwrite: boolean = false) {

  common.printLevel1Message(`Install Zowe main started task`);

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

  // check if user passed --generate
  const forceGen = !!std.getenv('ZWE_CLI_PARAMETER_GENERATE')
  if (forceGen) {
    initGenerate.execute();
  }

  // read JCL library and validate
  const jcllib = zoslib.verifyGeneratedJcl(ZOWE_CONFIG);
  if (!jcllib) {
    return common.printErrorAndExit(`Error ZWEL0319E: zowe.setup.dataset.jcllib does not exist, cannot run. Run 'zwe init', 'zwe init generate', or submit JCL ${prefix}.SZWESAMP(ZWEGENER) before running this command.`, undefined, 319);
  }

  // zowe.setup.security.stcs.* defined in defaults
  const security_stcs_zowe = ZOWE_CONFIG.zowe.setup.security.stcs.zowe;
  const security_stcs_zis = ZOWE_CONFIG.zowe.setup.security.stcs.zis;
  const security_stcsAux = ZOWE_CONFIG.zowe.setup.security.stcs.aux;

  [security_stcs_zowe, security_stcs_zis, security_stcsAux].forEach((mb: string) => {
    // STCs in target proclib
    if (zosdataset.isDatasetExists(`${proclib}(${mb})`)) {
      stcExistence = true;
      if (allowOverwrite) {
        // warning
        common.printMessage(`Warning ZWEL0300W: ${proclib}(${mb}) already exists. This data set member will be overwritten.`);
      } else {
        // warning
        common.printMessage(`Warning ZWEL0301W: ${proclib}(${mb}) already exists and will not be overwritten. For upgrades, you must use --allow-overwrite.`);
      }
    }
  });

  if (stcExistence == true && !allowOverwrite) {
    common.printMessage(`Skipped writing to ${proclib}. To write, you must use --allow-overwrite.`);
  }
  else {
    const authLoadlib = ZOWE_CONFIG.zowe?.setup?.dataset?.authLoadlib;
    const authPluginLib = ZOWE_CONFIG.zowe?.setup?.dataset?.authPluginLib;
    const DEFAULT_SUFFIX = '00';
    const DEFAULT_CMS_NAME = 'ZWESIS_STD';
    // zis and crossMemoryServerName are in defaults
    const zisSuffix = ZOWE_CONFIG.zowe.setup.dataset.parmlibMembers.zis.substring(6);
    // There is no schema validation (at this point) for crossMemoryServerName as it is in components
    // Check and take string or use defaults
    const cmsName = typeof ZOWE_CONFIG.components.zss.crossMemoryServerName === "string" ? ZOWE_CONFIG.components.zss.crossMemoryServerName.substring(0, 16) : DEFAULT_CMS_NAME;
    if (stcExistence == true) {
      zosJes.printAndHandleJcl(`//'${jcllib}(ZWERSTC)'`, `ZWERSTC`, jcllib, prefix, false, true);
    }
    let auxStc = false;
    let zisStc = false;
    let launcherStc = authLoadlib === undefined ? true : false;
    // Member suffix or crossMemoryServeName different, update ZIS
    if (zisSuffix != DEFAULT_SUFFIX || cmsName != DEFAULT_CMS_NAME) {
      zisStc = true;
    }
    // Change both STCs if DD not defined or same as defaults
    if (!authLoadlib || !authPluginLib || authPluginLib == authLoadlib || authPluginLib == `${prefix}.SZWEAUTH`) {
      auxStc = true;
      zisStc = true;
    }
    let membersToChange: string[] = [];
    auxStc && membersToChange.push('ZWESASTC');
    zisStc && membersToChange.push('ZWESISTC');
    launcherStc && membersToChange.push('ZWESLSTC');
    membersToChange.forEach((mb) => {
      let jclContent = zosdataset.readMember(`${jcllib}(${mb})`);
      if (jclContent) {
        // Only for ZWESISTC to possibly change suffix or cross memory server name
        if (mb == 'ZWESISTC') {
          if (zisSuffix != DEFAULT_SUFFIX || cmsName != DEFAULT_CMS_NAME) {
            // Original line fit
            jclContent = jclContent.replace(/NAME='ZWESIS_STD',MEM=00,RGN=0M/, `NAME='${cmsName}',MEM=${zisSuffix},RGN=0M`);
          }
        }
        // Common for all STCs: authLoadlib not defined, replace by default prefix + SZWEAUTH
        if (!authLoadlib) {
          jclContent = jclContent.replace(/\{zowe\.setup\.dataset\.authLoadlib\}/i, `${prefix}.SZWEAUTH`);
        }
        // // Common for zis & aux STCs: delete DD for authPluginLib, if not defined or same as authLoadlib
        let pluginRegex: any = undefined;
        if (!authPluginLib || authPluginLib == authLoadlib || authPluginLib == `${prefix}.SZWEAUTH`) {
          // Regex for DD statement with no label
          pluginRegex = /^\/\/[\ ]+DD[\ ]+/;
        }
        if (pluginRegex) {
          let jclContentArray = jclContent.split('\n');
          let indexOfPluginLib = -1;
          for (let i = 0; i < jclContentArray.length; i++) {
            if (pluginRegex.test(jclContentArray[i]) == true) {
              indexOfPluginLib = i;
              break;
            }
          }
          if (indexOfPluginLib != -1) {
            jclContentArray.splice(indexOfPluginLib, 2);  // First line DD, second line DISP
            jclContent = jclContentArray.join('\n');
          }
        }
        if (!std.getenv('ZWE_CLI_PARAMETER_DRY_RUN') && !std.getenv('ZWE_CLI_PARAMETER_SECURITY_DRY_RUN')) {
          zosdataset.updateMember(`${jcllib}(${mb})`, jclContent);
        }
        common.printMessage(`Template JCL: ${prefix}.SZWESAMP(${mb}) , Executable JCL: ${jcllib}(${mb})`);
        common.printMessage(`--- Modified JCL Content ---`);
        common.printMessage(jclContent);
        common.printMessage(`--- End of JCL ---`);
      }
    });

    zosJes.printAndHandleJcl(`//'${jcllib}(ZWEISTC)'`, `ZWEISTC`, jcllib, prefix, false, true);

    common.printLevel2Message(`Zowe main started tasks are installed successfully.`);
}

}
