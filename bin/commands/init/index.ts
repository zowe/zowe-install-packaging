/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
  
  SPDX-License-Identifier: EPL-2.0
  
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as os from 'cm_os';
import * as shell from '../../libs/shell';
import * as zoslib from '../../libs/zos';
import * as json from '../../libs/json';
import * as zosJes from '../../libs/zos-jes';
import * as zosDataset from '../../libs/zos-dataset';
import * as common from '../../libs/common';
import * as config from '../../libs/config';
import * as node from '../../libs/node';
import * as java from '../../libs/java';

import * as initGenerate from './generate/index';
import * as initMvs from './mvs/index';
import * as initVsam from './vsam/index';
import * as initApfAuth from './apfauth/index';
import * as initSecurity from './security/index';
//import * as initCertificate from './certificate/index';
import * as initStc from './stc/index';

export function execute(allowOverwrite?: boolean, dryRun?: boolean, ignoreSecurityFailures?: boolean, updateConfig?: boolean) {
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
  if (!configNodeHome || configNodeHome == 'DETECT') {
    node.requireNode();
    newNodeHome=std.getenv('NODE_HOME');
  }

  // java.home
  let newJavaHome;
  const configJavaHome=zoweConfig.java?.home;
  // only try to update if it's not defined
  if (!configJavaHome || configJavaHome == 'DETECT') {
    java.requireJava();
    newJavaHome=std.getenv('JAVA_HOME');
  }

  // zowe.runtimeDirectory
  let newZoweRuntimeDir;
  // do we have zowe.runtimeDirectory defined in zowe.yaml?
  const configRuntimeDir = zoweConfig.zowe?.runtimeDirectory;
  if (configRuntimeDir) {
    let realPathResult = os.realpath(configRuntimeDir);
    if (realPathResult[1] != 0 || realPathResult[0] != std.getenv('ZWE_zowe_runtimeDirectory')) {
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
      json.updateZoweYamlFromObj(std.getenv('ZWE_CLI_PARAMETER_CONFIG'), updateObj);

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

  initGenerate.execute(dryRun);
  initMvs.execute(allowOverwrite);
  initVsam.execute(allowOverwrite, dryRun, updateConfig);
  if (std.getenv("ZWE_CLI_PARAMETER_SKIP_SECURITY_SETUP") != 'true') {
    initApfAuth.execute();
    initSecurity.execute(dryRun, ignoreSecurityFailures);
  }
  // TODO: init certificate remains shell code for now due to complexity.
  let result = shell.execSync('sh', '-c', `ZWE_PRIVATE_CLI_LIBRARY_LOADED= ${std.getenv('ZWE_zowe_runtimeDirectory')}/bin/zwe init certificate ${dryRun?'--dry-run':''} ${updateConfig?'--update-config':''} ${allowOverwrite?'--allow-overwrite':''} ${ignoreSecurityFailures?'--ignore-security-failures':''} -c "${std.getenv('ZWE_CLI_PARAMETER_CONFIG')}"`);
  initStc.execute(allowOverwrite);

  common.printLevel1Message(`Zowe is configured successfully.`);
}
