/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
  
  SPDX-License-Identifier: EPL-2.0
  
  Copyright Contributors to the Zowe Project.
*/

import * as zoslib from '../../../libs/zos';
import * as zosJes from '../../../libs/zos-jes';
import * as zosdataset from '../../../libs/zos-dataset';
import * as common from '../../../libs/common';
import * as config from '../../../libs/config';
import * as stringlib from '../../../libs/string';

export function execute(allowOverwrite?: boolean) {
  common.printLevel1Message(`Initialize Zowe custom data sets`);
  common.requireZoweYaml();
  const ZOWE_CONFIG = config.getZoweConfig();
  
  const datasets = ['parmlib', 'authLoadlib', 'authPluginLib'];

  const prefix = ZOWE_CONFIG.zowe.setup?.dataset?.prefix;
  if (!prefix) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }

  const jcllib = zoslib.verifyGeneratedJcl(ZOWE_CONFIG);
  if (!jcllib) {
    common.printErrorAndExit(`Error ZWEL0999E: zowe.setup.dataset.jcllib does not exist, cannot run. Run 'zwe init', 'zwe init generate', or submit JCL ${prefix}.SZWESAMP(ZWEGENER) before running this command.`, undefined, 999);
  }

  let runALoadlibCreate: boolean;

  common.printMessage(`Create data sets if they do not exist`);
  let skippedDatasets: boolean = false;
  let needCleanup: boolean = false;
  let needAuthCleanup: boolean = false;
  
  for (let i = 0; i < datasets.length; i++) {
    let key = datasets[i];
    // read def and validate
    let skip: boolean = false;
    const ds = ZOWE_CONFIG.zowe.setup?.dataset ? ZOWE_CONFIG.zowe.setup.dataset[key] : undefined;
    if (!ds) {
      // authLoadlib can be empty
      if (key == 'authLoadlib') {
        skip=true;
      } else {
        common.printErrorAndExit(`Error ZWEL0157E: ${key} (zowe.setup.dataset.${key}) is not defined in Zowe YAML configuration file.`, undefined, 157);
      }
    }
    if (!skip) {
      if (key == 'authLoadlib') {
        runALoadlibCreate = ds == (prefix+'.SZWEAUTH') ? false : true;
      }

      const datasetExists=zosdataset.isDatasetExists(ds);
      if (datasetExists) {
        if (allowOverwrite) {
          if (key != 'authLoadlib') {
            needCleanup = true;
          } else {
            needAuthCleanup = true;
          }
          common.printMessage(`Warning ZWEL0300W: ${ds} already exists. Members in this data set will be overwritten.`);
        } else {
          skippedDatasets = true;
          common.printMessage(`Warning ZWEL0301W: ${ds} already exists and will not be overwritten. For upgrades, you must use --allow-overwrite.`);
        }
      }
    }
  }

  if (skippedDatasets && !allowOverwrite) {
    common.printMessage(`Skipped writing to a dataset. To write, you must use --allow-overwrite.`);
  } else {
    if (allowOverwrite && needCleanup) {
      zosJes.printAndHandleJcl(`//'${jcllib}(ZWERMVS)'`, `ZWERMVS`, jcllib, prefix, false, true);
    }
    if (allowOverwrite && needAuthCleanup) {
      zosJes.printAndHandleJcl(`//'${jcllib}(ZWERMVS2)'`, `ZWERMVS2`, jcllib, prefix, false, true);
    }
      
    zosJes.printAndHandleJcl(`//'${jcllib}(ZWEIMVS)'`, `ZWEIMVS`, jcllib, prefix);
    if (runALoadlibCreate === true) {
      zosJes.printAndHandleJcl(`//'${jcllib}(ZWEIMVS2)'`, `ZWEIMVS2`, jcllib, prefix);
    }
  }

  common.printLevel2Message(`Zowe custom data sets are initialized successfully.`);
}
