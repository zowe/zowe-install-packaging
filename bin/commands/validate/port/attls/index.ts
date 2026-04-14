/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as common from '../../../../libs/common';
import * as config from '../../../../libs/config';
import * as component from '../../../../libs/component';
import * as shell from '../../../../libs/shell';

const COMMAND_NAME = 'zwe-validate-port-attls';

export function execute(quitOnError?: boolean, componentName?: string): number {
  common.requireZoweYaml();
  let hasErrors = false;
  const ZOWE_CONFIG = config.getZoweConfig();
  const enabledComponents = component.getEnabledComponents();
  let checkedComponents;
  if (componentName && componentName.trim().length > 0) {
    if (enabledComponents.includes(componentName)) {
      checkedComponents = [componentName];
    } else {
      let errMessageReason = 'enabled';
      if (ZOWE_CONFIG.components[componentName] == null) {
          errMessageReason = 'defined';
      }
      const errMsg = `Component '${componentName}' is not ${errMessageReason}. Skipping port ATTLS validation.`;
      if (!quitOnError) {
        common.printError(`ZWEL0363W: ${errMsg}`);
        return 1;
      } else {
        common.printErrorAndExit(`ZWEL0364E: ${errMsg}`);
        return 1;
      }
    }
  } else {
    checkedComponents = enabledComponents;
  }

  // Get userid from YAML configuration
  const zoweUserId = ZOWE_CONFIG.zowe?.setup?.security?.users?.zowe;
  if (!zoweUserId) {
    const errMsg = 'zowe.setup.security.users.zowe is not configured. Cannot validate ATTLS port.';
    if (!quitOnError) {
      common.printError(`ZWEL0363W: ${errMsg}`);
      return 1;
    } else {
      common.printErrorAndExit(`ZWEL0364E: ${errMsg}`);
      return 1;
    }
  }

  let detectAttlsPortPath = std.getenv('ZWE_zowe_runtimeDirectory') + '/bin/utils/detect-attls-port';
  let myJobname = std.getenv('_BPX_JOBNAME');

  common.printFormattedInfo(common.MSG_KEY, COMMAND_NAME, `Checking ATTLS ports of ${checkedComponents.length} enabled components`);
  let failedCount = 0;
  
  for (let i = 0; i < checkedComponents.length; i++) {
    let componentName = checkedComponents[i];
    let port = ZOWE_CONFIG.components[componentName].port;
    
    // Skip if component doesn't have port configured
    if (!port) {
      common.printFormattedDebug(common.MSG_KEY, COMMAND_NAME, `${componentName}: Component has no port, skipped.`);
      continue;
    }

    // ATTLS direction is hardcoded to Inbound (1) for now
    let attlsDirection = 1; // Inbound

    let componentManifest: any;
    const componentDir = component.findComponentDirectory(componentName);
    if (componentDir) {
      componentManifest = component.getManifest(componentDir);
    }
    let jobname = component.getJobnameForComponent(componentName, componentManifest);

    // Get listen address
    let listenAddress = '0.0.0.0';
    if (ZOWE_CONFIG.components[componentName].zowe?.network?.server?.listenAddresses) {
      listenAddress = ZOWE_CONFIG.components[componentName].zowe.network.server.listenAddresses[0];
    } else if (ZOWE_CONFIG.zowe?.network?.server?.listenAddresses) {
      listenAddress = ZOWE_CONFIG.zowe.network.server.listenAddresses[0];
    }
    
    if (jobname) {
      std.setenv('_BPX_JOBNAME', jobname);
      common.printFormattedDebug(common.MSG_KEY, COMMAND_NAME, 
        `${componentName}: Checking if ATTLS is enabled for port ${port} for userid ${zoweUserId} on host ${listenAddress}, jobname ${jobname}`);
    } else {
      common.printFormattedDebug(common.MSG_KEY, COMMAND_NAME, 
        `${componentName}: Checking if ATTLS is enabled for port ${port} for userid ${zoweUserId} on host ${listenAddress} with default jobname`);
    }
    
    // Call detect-attls-port binary
    let result = shell.execOutSync(detectAttlsPortPath, 
      '--serverPort', port.toString(), 
      '--serverHost', listenAddress,
      '--direction', attlsDirection.toString());
    
    if (jobname) {
      // restore original jobname
      std.setenv('_BPX_JOBNAME', myJobname);
    }

    if (result.rc) {
      failedCount++;
      if (result.out) {
        common.printDebug(result.out);
      }
      if (jobname) {
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, 
          `ZWEL0365E: ${componentName}: No AT-TLS rule identified on ${listenAddress}:${port} for user ${zoweUserId} and jobname ${jobname}`);
      } else {
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, 
          `ZWEL0365E: ${componentName}: No AT-TLS rule identified on ${listenAddress}:${port} for user ${zoweUserId}`);
      }
      hasErrors = true;
    } else if (result.out) {
      common.printDebug(result.out);
    }
  }

  if (!hasErrors) {
    common.printFormattedInfo(common.MSG_KEY, COMMAND_NAME, `Zowe port ATTLS validation passed.`);
    return 0;
  } else if (!quitOnError) {
    common.printFormattedError(common.MSG_KEY, COMMAND_NAME, 
      `ZWEL0366E: ${failedCount} Zowe port ATTLS validation(s) failed, review output for action items before running Zowe.`);
    return failedCount;
  } else {
    // It is possible that the ATTLS check failed due to missing detect-attls-port binary or other unexpected error, so we want to provide a hint about how to bypass the check if needed instead of just exiting with error code.
    common.printFormattedError(common.MSG_KEY, COMMAND_NAME, 
      `Zowe port ATTLS validation failed. This check can be dismissed with YAML value "zowe.launchScript.startupChecks.attls: warn"`);
    common.printErrorAndExit(
      `ZWEL0366E: ${failedCount} Zowe port ATTLS validation(s) failed, review output for action items before running Zowe.`, 
      undefined, 8);
    return failedCount;
  }
}
