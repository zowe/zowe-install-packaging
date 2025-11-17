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
import * as zosJes from '../../../libs/zos-jes';
import * as zosdataset from '../../../libs/zos-dataset';
import * as common from '../../../libs/common';
import * as config from '../../../libs/config';
import * as initGenerate from '../generate/index';

export function execute(allowOverwrite?: boolean) {
  common.printLevel1Message(`Initialize Zowe custom data sets`);
  common.requireZoweYaml();
  const ZOWE_CONFIG = config.getZoweConfig();

  const prefix = ZOWE_CONFIG.zowe.setup?.dataset?.prefix;
  if (!prefix) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }

  // For V4: if components.zss.enabled = false => no need to create parmlib
  const parmlib = ZOWE_CONFIG.zowe.setup?.dataset?.parmlib ? ZOWE_CONFIG.zowe.setup.dataset.parmlib : undefined;
  if (!parmlib) {
      common.printErrorAndExit(`Error ZWEL0157E: zowe.setup.dataset.parmlib is not defined in Zowe YAML configuration file.`, undefined, 157);
  }

  // check if user passed --generate
  const forceGen = !!std.getenv('ZWE_CLI_PARAMETER_GENERATE')
  if (forceGen) {
    initGenerate.execute();
  }

  const jcllib = zoslib.verifyGeneratedJcl(ZOWE_CONFIG);
  if (!jcllib) {
    common.printErrorAndExit(`Error ZWEL0319E: zowe.setup.dataset.jcllib does not exist, cannot run. Run 'zwe init', 'zwe init generate', or submit JCL ${prefix}.SZWESAMP(ZWEGENER) before running this command.`, undefined, 319);
  }

  common.printMessage(`Create data sets if they do not exist`);

  // If authLoadlib is not defined, we'll use "zowe.setup.dataset.prefix.SZWEAUTH"
  // This dataset will be kept (allow-overwrite has no effect)
  const authLoadlibDefaults = `${prefix}.SZWEAUTH`
  const authLoadlibConfig = ZOWE_CONFIG.zowe.setup?.dataset ? ZOWE_CONFIG.zowe.setup.dataset.authLoadlib : undefined;
  let authPluginLib = ZOWE_CONFIG.zowe.setup?.dataset ? ZOWE_CONFIG.zowe.setup.dataset.authPluginLib : undefined;
  // If authPluginLib defined, it must be different from defaults and authLoadlib
  if (authPluginLib) {
    if (authPluginLib == authLoadlibDefaults || authPluginLib == authLoadlibConfig) {
      authPluginLib = undefined;
    }
  }

  let actions = {
    parmlib: {
      ds: parmlib,
      jclSuffix: '',
      exist: false, create: false, delete: false
    },
    authloadlib: {
      ds: authLoadlibDefaults == authLoadlibConfig ? undefined : authLoadlibConfig,
      jclSuffix: '2',
      exist: false, create: false, delete: false
    },
    authpluginlib: {
      ds: authPluginLib,
      jclSuffix: '1',
      exist: false, create: false, delete: false
    }
  }

  let skipDatasets = false;
  for (let a in actions) {
    if (actions[a].ds) {
      actions[a].exist = zosdataset.isDatasetExists(actions[a].ds);
    }
    actions[a].delete = actions[a].exist && allowOverwrite;
    if (actions[a].delete) {
      actions[a].create = true;
      common.printMessage(`Warning ZWEL0300W: ${actions[a].ds} already exists. Members in this data set will be overwritten.`);
    } else {
      if (actions[a].ds) {
        if (actions[a].exist) {
          common.printMessage(`Warning ZWEL0301W: ${actions[a].ds} already exists and will not be overwritten. For upgrades, you must use --allow-overwrite.`);
          skipDatasets = true;
        } else {
          actions[a].create = true;
        }
      }
    }
  }

  if (skipDatasets) {
    common.printMessage(`Skipped writing to a dataset. To write, you must use --allow-overwrite.`);
    common.printLevel2Message(`Zowe custom data sets are initialized successfully.`);
    std.exit(0);
  }

  for (let a in actions) {
    if (actions[a].delete) {
      const jclJobName = `ZWERMVS${actions[a].jclSuffix}`
      zosJes.printAndHandleJcl(`//'${jcllib}(${jclJobName})'`, jclJobName, jcllib, prefix);
    }
    if (actions[a].create) {
      const jclJobName = `ZWEIMVS${actions[a].jclSuffix}`
      zosJes.printAndHandleJcl(`//'${jcllib}(${jclJobName})'`, jclJobName, jcllib, prefix);
    }
  }

  common.printLevel2Message(`Zowe custom data sets are initialized successfully.`);
}
