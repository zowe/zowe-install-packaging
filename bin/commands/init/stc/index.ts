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
    if (stcExistence == true) {
      zosJes.printAndHandleJcl(`//'${jcllib}(ZWERSTC)'`, `ZWERSTC`, jcllib, prefix, false, true);
    }

    zosJes.printAndHandleJcl(`//'${jcllib}(ZWEISTC)'`, `ZWEISTC`, jcllib, prefix, false, true);

    common.printLevel2Message(`Zowe main started tasks are installed successfully.`);
  }
}
