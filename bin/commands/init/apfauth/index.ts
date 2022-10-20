/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'std';
import * as zoslib from '../../../libs/zos';
import * as zosdataset from '../../../libs/zos-dataset';
import * as common from '../../../libs/common';
import * as stringlib from '../../../libs/string';
import * as shell from '../../../libs/shell';
import * as config from '../../../libs/config';

export function execute() {

  common.printLevel1Message(`APF authorize load libraries`);

  // constants
  const AUTH_LIBS = ['authLoadlib', 'authPluginLib'];

  // Validation
  common.requireZoweYaml();
  const zoweConfig = config.getZoweConfig();

  // read prefix and validate
  const prefix=zoweConfig.zowe?.setup?.dataset?.prefix;
  if (!prefix) {
    common.printErrorAndExit(`Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file.`, undefined, 157);
  }

  // APF authorize loadlib
  let jobHasFailures;
  AUTH_LIBS.forEach((key:string)=> {
    // read def and validate
    let ds=zoweConfig.zowe?.setup?.dataset ? zoweConfig.zowe.setup.dataset[key] : undefined;
    if (!ds) {
      // authLoadlib can be empty
      if (key == "authLoadlib") {
        ds=`${prefix}.${std.getenv('ZWE_PRIVATE_DS_SZWEAUTH')}`;
      } else {
        common.printErrorAndExit(`Error ZWEL0157E: zowe.setup.dataset.${key} is not defined in Zowe YAML configuration file.`, undefined, 157);
      }
    }

    common.printMessage(`APF authorize ${ds}`);
    const rc = zosdataset.apfAuthorizeDataset(ds);
    if (rc!=0) {
      if (std.getenv('ZWE_CLI_PARAMETER_IGNORE_SECURITY_FAILURES') == "true") {
        jobHasFailures=true;
      } else {
        std.exit(rc);
      }
    } else {
      common.printDebug(`- APF authorized successfully.`);
    }
  });

  // exit message
  if (jobHasFailures === true) {
    common.printLevel2Message(`Failed to APF authorize Zowe load libraries. Please check log for details.`);
  } else {
    common.printLevel2Message(`Zowe load libraries are APF authorized successfully.`);
  }
}
