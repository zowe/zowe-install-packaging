/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as zosJes from '../../../libs/zos-jes';
import * as zoslib from '../../../libs/zos';
import * as common from '../../../libs/common';
import * as config from '../../../libs/config';

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
    return common.printErrorAndExit(`Error ZWEL0999E: zowe.setup.dataset.jcllib does not exist, cannot run. Run 'zwe init', 'zwe init generate', or submit JCL ${prefix}.SZWESAMP(ZWEGENER) before running this command.`, undefined, 999);
  }

  
  ['authLoadlib', 'authPluginLib'].forEach((key)=> {
    if (!ZOWE_CONFIG.zowe?.setup?.dataset || !ZOWE_CONFIG.zowe?.setup?.dataset[key]) {
      common.printErrorAndExit(`Error ZWEL0157E: zowe.setup.dataset.${key} is not defined in Zowe YAML configuration file.`, undefined, 157);
    }
  });

  
  zosJes.printAndHandleJcl(`//'${jcllib}(ZWEIAPF)'`, `ZWEIAPF`, jcllib, prefix);  
  common.printLevel2Message(`Zowe load libraries are APF authorized successfully.`);
}
