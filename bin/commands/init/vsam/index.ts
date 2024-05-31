/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
  
  SPDX-License-Identifier: EPL-2.0
  
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as zoslib from '../../../libs/zos';
import * as json from '../../../libs/json';
import * as zosJes from '../../../libs/zos-jes';
import * as zosDataset from '../../../libs/zos-dataset';
import * as common from '../../../libs/common';
import * as config from '../../../libs/config';

export function execute(allowOverwrite?: boolean, dryRun?: boolean, updateConfig?: boolean) {
  common.printLevel1Message(`Initialize Zowe custom data sets`);
  common.requireZoweYaml();
  const ZOWE_CONFIG = config.getZoweConfig();
  
  const cachingStorage = ZOWE_CONFIG.components !== undefined ? ZOWE_CONFIG.components['caching-service']?.storage?.mode : undefined;
  if (!cachingStorage || (cachingStorage.toUpperCase() != 'VSAM')) {
    common.printError(`Warning ZWEL0301W: Zowe Caching Service is not configured to use VSAM. Command skipped.`);
    return;
  }

  const prefix=ZOWE_CONFIG.zowe.setup?.dataset?.prefix;
  if (!prefix) {
    return common.printErrorAndExit(`Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }

  const jcllib = zoslib.verifyGeneratedJcl(ZOWE_CONFIG);
  if (!jcllib) {
    return common.printErrorAndExit(`Error ZWEL0319E: zowe.setup.dataset.jcllib does not exist, cannot run. Run 'zwe init', 'zwe init generate', or submit JCL ${prefix}.SZWESAMP(ZWEGENER) before running this command.`, undefined, 319);
  }

  const mode = ZOWE_CONFIG.zowe.setup?.vsam?.mode;
  if (!mode) {
    return common.printErrorAndExit(`Error ZWEL0157E: VSAM parameter (zowe.setup.vsam.mode) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }
  let keys = mode == 'NONRLS' ? ['volume', 'name'] : ['storageClass', 'name'];

  keys.forEach((key)=> {
    if (!ZOWE_CONFIG.zowe.setup.vsam || !ZOWE_CONFIG.zowe.setup.vsam[key]) {
      return common.printErrorAndExit(`Error ZWEL0157E: VSAM parameter (zowe.setup.vsam.${key}) is not defined in Zowe YAML configuration file.`, undefined, 157);
    }
  });

  const name = ZOWE_CONFIG.zowe.setup.vsam.name;

  const vsamExistence = zosDataset.isVsamDatasetExists(name);
  if (vsamExistence && allowOverwrite) {
    zosJes.printAndHandleJcl(`//'${jcllib}(ZWECSRVS)'`, `ZWECSRVS`, jcllib, prefix, false, true);
  } else if (vsamExistence) {
    return common.printErrorAndExit(`Error ZWEL0158E: ${name} already exists.`, undefined, 158);
  }

  zosJes.printAndHandleJcl(`//'${jcllib}(ZWECSVSM)'`, `ZWECSVSM`, jcllib, prefix);
  if (!dryRun && updateConfig) {
    json.updateZoweYaml(std.getenv('ZWE_CLI_PARAMETER_CONFIG_ORIG'), '.components.caching-service.storage.vsam.name', name);
    common.printLevel2Message(`Zowe configuration is updated successfully.`);
  }
  
  common.printLevel2Message(`Zowe Caching Service VSAM storage is created successfully.`);
}
