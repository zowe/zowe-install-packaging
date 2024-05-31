/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as zos from 'zos';
import * as common from '../../../libs/common';
import * as config from '../../../libs/config';
import * as zoslib from '../../../libs/zos';
import * as zosJes from '../../../libs/zos-jes';

export function execute(dryRun?: boolean, ignoreSecurityFailures?: boolean) {
  common.printLevel1Message(`Run Zowe security configurations`);

  // Validation
  common.requireZoweYaml();
  const ZOWE_CONFIG = config.getZoweConfig();

  // read prefix and validate
   const prefix=ZOWE_CONFIG.zowe.setup?.dataset?.prefix;
  if (!prefix) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }
  // read JCL library and validate
  const jcllib = zoslib.verifyGeneratedJcl(ZOWE_CONFIG);
  if (!jcllib) {
    return common.printErrorAndExit(`Error ZWEL0319E: zowe.setup.dataset.jcllib does not exist, cannot run. Run 'zwe init', 'zwe init generate', or submit JCL ${prefix}.SZWESAMP(ZWEGENER) before running this command.`, undefined, 319);
  }

  let securityProduct = zos.getEsm();
  if (!securityProduct || securityProduct == 'NONE') {
    securityProduct = ZOWE_CONFIG.zowe.setup?.security?.product;
    if (!securityProduct) {
      common.printErrorAndExit(`Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file.`, undefined, 157);
    }
  }

  ['admin', 'stc', 'sysProg'].forEach((key)=> {
    if (!ZOWE_CONFIG.zowe.setup?.security?.groups || !ZOWE_CONFIG.zowe.setup?.security?.groups[key]) {
      common.printErrorAndExit(`Error ZWEL0157E: (zowe.setup.dataset.groups.${key}) is not defined in Zowe YAML configuration file.`, undefined, 157);
    }
  });
  ['zowe', 'zis'].forEach((key)=> {
    if (!ZOWE_CONFIG.zowe.setup?.security?.users || !ZOWE_CONFIG.zowe.setup?.security?.users[key]) {
      common.printErrorAndExit(`Error ZWEL0157E: (zowe.setup.dataset.users.${key}) is not defined in Zowe YAML configuration file.`, undefined, 157);
    }
  });
  ['zowe', 'zis', 'aux'].forEach((key)=> {
    if (!ZOWE_CONFIG.zowe.setup?.security?.stcs || !ZOWE_CONFIG.zowe.setup?.security?.stcs[key]) {
      common.printErrorAndExit(`Error ZWEL0157E: (zowe.setup.dataset.stcs.${key}) is not defined in Zowe YAML configuration file.`, undefined, 157);
    }
  });

  const securityPrefix = securityProduct.substring(0,3);

  if (zos.getZosVersion() < 0x1020500) {
    zosJes.printAndHandleJcl(`//'${jcllib}(ZWEI${securityPrefix}Z)'`, `ZWEI${securityPrefix}Z`, jcllib, prefix, false, ignoreSecurityFailures);
  }

  zosJes.printAndHandleJcl(`//'${jcllib}(ZWEI${securityPrefix})'`, `ZWEI${securityPrefix}`, jcllib, prefix, false, ignoreSecurityFailures);
  common.printMessage(``);
  common.printMessage(`WARNING: Due to the limitation of the ZWEI${securityPrefix} job, exit with 0 does not mean`);
  common.printMessage(`         the job is fully successful. Please check the job log to determine`);
  common.printMessage(`         if there are any inline errors.`);
  common.printMessage(``);
}
