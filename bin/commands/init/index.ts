/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'std';
import * as node from '../../libs/node';
import * as java from '../../libs/java';
import * as zoslib from '../../libs/zos';
import * as common from '../../libs/common';
import * as stringlib from '../../libs/string';
import * as shell from '../../libs/shell';
import * as config from '../../libs/config';
import * as json from '../../libs/json';
import * as initMvs from './mvs/index';
import * as initVsam from './vsam/index';
import * as initApfAuth from './apfauth/index';
import * as initSecurity from './security/index';
//import * as initCertificate from './certificate/index';
import * as initStc from './stc/index';

export function execute() {
  common.printLevel0Message(`Configure Zowe`);

  // Validation
  common.requireZoweYaml();

  // Read job name and validate
  const zoweConfig = config.getZoweConfig();

  
  common.printLevel1Message(`Check if need to update runtime directory, Java and/or node.js settings in Zowe YAML configuration`);
  // node.home
  let newNodeHome;
  const configNodeHome=zoweConfig.node?.home;
  // only try to update if it's not defined
  if (!configNodeHome) {
    node.requireNode();
    newNodeHome=std.getenv('NODE_HOME');
  }

  // java.home
  let newJavaHome;
  const configJavaHome=zoweConfig.java?.home;
  // only try to update if it's not defined
  if (!configJavaHome) {
    java.requireJava();
    newJavaHome=std.getenv('JAVA_HOME');
  }

  // zowe.runtimeDirectory
  let newZoweRuntimeDir;
  // do we have zowe.runtimeDirectory defined in zowe.yaml?
  const configRuntimeDir = zoweConfig.zowe?.runtimeDirectory;
  if (configRuntimeDir) {
    if (configRuntimeDir != std.getenv('ZWE_zowe_runtimeDirectory')) {
      common.printErrorAndExit(`Error ZWEL0105E: The Zowe YAML config file is associated to Zowe runtime "${configRuntimeDir}", which is not same as where zwe command is located.`, undefined, 105);
    }
  } else {
    newZoweRuntimeDir = std.getenv('ZWE_zowe_runtimeDirectory');
  }

  if (newNodeHome || newJavaHome || newZoweRuntimeDir) {
    if (std.getenv("ZWE_CLI_PARAMETER_UPDATE_CONFIG") == "true") {
      let updateObj:any = {};
      if (newNodeHome) {
        updateObj.node = {home: newNodeHome};
      }
      if (newJavaHome) {
        updateObj.java = {home: newJavaHome};
      }
      if (newZoweRuntimeDir) {
        updateObj.zowe = {runtimeDirectory: newZoweRuntimeDir};
      }
      json.updateZoweYamlFromObj(std.getenv('ZOWE_CLI_PARAMETER_CONFIG'), updateObj);

      common.printLevel2Message(`Runtime directory, Java and/or node.js settings are updated successfully.`);
    } else {
      common.printMessage(`These configurations need to be added to your YAML configuration file:`);
      common.printMessage(``);
      if (newZoweRuntimeDir) {
        common.printMessage(`zowe:`);
        common.printMessage(`  runtimeDirectory: "${newZoweRuntimeDir}"`);
      }
      if (newNodeHome) {
        common.printMessage(`node:`);
        common.printMessage(`  home: "${newNodeHome}"`);
      }
      if (newJavaHome) {
        common.printMessage(`java:`);
        common.printMessage(`  home: "${newJavaHome}"`);
      }

      common.printLevel2Message(`Please manually update "${std.getenv('ZWE_CLI_PARAMETER_CONFIG')}" before you start Zowe.`);
    }
  } else {
    common.printLevel2Message(`No need to update runtime directory, Java and node.js settings.`);
  }

  initMvs.execute();
  initVsam.execute();
  if (std.getenv("ZWE_CLI_PARAMETER_SKIP_SECURITY_SETUP") != "true") {
    initApfAuth.execute();
    initSecurity.execute();
  }
//  initCertificate.execute();
  initStc.execute();

  common.printLevel1Message(`Zowe is configured successfully.`);
}
