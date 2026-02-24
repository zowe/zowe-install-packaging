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
import * as common from '../../../libs/common';
import * as config from '../../../libs/config';
import * as json from '../../../libs/json';
import * as zoslib from '../../../libs/zos';
import * as zosJes from '../../../libs/zos-jes';
import * as initGenerate from '../generate/index';

export function execute(dryRun?: boolean, ignoreSecurityFailures?: boolean) {
  common.printLevel1Message(`Run Zowe security configurations`);

  // Validation
  common.requireZoweYaml();
  const ZOWE_CONFIG = config.getZoweConfig();

  // read prefix and validate (zowe.setup.dataset in defaults)
  const prefix=ZOWE_CONFIG.zowe.setup.dataset.prefix;
  if (!prefix) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file.`, undefined, 157);
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

  let securityProduct: string;
  let esmWarning = false;
  const securityProductReal = zos.getEsm();
  // zowe.setup.security.product in defaults
  const securityProductConfig = ZOWE_CONFIG.zowe.setup.security.product;
  if (securityProductReal && securityProductReal != 'NONE') {
      securityProduct = securityProductReal;
      if (securityProductReal != securityProductConfig) {
        esmWarning = true;
      }
  } else {
      securityProduct = securityProductConfig;
  }

  const securityPrefix = securityProduct.substring(0,3);

  if (zos.getZosVersion() < 0x1020500) {
    zosJes.printAndHandleJcl(`//'${jcllib}(ZWEI${securityPrefix}Z)'`, `ZWEI${securityPrefix}Z`, jcllib, prefix, false, ignoreSecurityFailures);
  }

  zosJes.printAndHandleJcl(`//'${jcllib}(ZWEI${securityPrefix})'`, `ZWEI${securityPrefix}`, jcllib, prefix, false, ignoreSecurityFailures);
  common.printMessage(``);
  common.printMessage(`WARNING: Due to the limitation of the ZWEI${securityPrefix} job, exit with 0 does not mean`);
  common.printMessage(`         the job is fully successful. Please check the job log to determine`);
  common.printMessage(`         if there are any messages indicating a problem.`);
  if (esmWarning) {
    common.printMessage(``);
    const updateConfig = !!std.getenv('ZWE_CLI_PARAMETER_UPDATE_CONFIG');
    const configOrig = std.getenv('ZWE_PRIVATE_CONFIG_ORIG');
    common.printLevel1Message(`Update security configuration to ${configOrig}`);
    if (!updateConfig) {
      common.printMessage(`Please manually update to these values:`);
      common.printMessage('zowe:');
      common.printMessage('  setup:');
      common.printMessage('    security');
      common.printMessage(`      product: ${securityProductReal}`);
    } else {
      json.updateZoweYaml(configOrig, '.zowe.setup.security.product', securityProductReal);
      common.printLevel2Message(`Zowe configuration is updated successfully.`);
    }
}
  common.printMessage(``);
}
