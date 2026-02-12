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

const COMMAND_NAME = 'zwe-validate-port-available';

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
      const errMsg = `Component '${componentName}' is not ${errMessageReason}. Skipping port validation.`;
      if (!quitOnError) {
        common.printError(`ZWEL0356W: ${errMsg}`);
        return 1;
      } else {
        common.printErrorAndExit(`ZWEL0356E: ${errMsg}`);
        return 1;
      }
    }
  } else {
    checkedComponents = enabledComponents;
  }


  let bindUtilPath = std.getenv('ZWE_zowe_runtimeDirectory') + '/bin/utils/bind-test';
  let myJobname = std.getenv('_BPX_JOBNAME');

  common.printFormattedInfo(common.MSG_KEY, COMMAND_NAME, `Checking ports of ${checkedComponents.length} enabled components`);
  let failedCount = 0;
  for (let i = 0; i < checkedComponents.length; i++) {
    let componentName = checkedComponents[i];
    let port = ZOWE_CONFIG.components[componentName].port;
    if (component.isComponentInAPIMLModulith(componentName)) {
      if (componentName == 'gateway') {
        port = ZOWE_CONFIG.components.apiml.port ?? port;
      } else if (componentName != 'discovery') {
        continue;
      }
    }

    if (port) {
      let componentManifest: any;
      const componentDir = component.findComponentDirectory(componentName);
      if (componentDir) {
        componentManifest = component.getManifest(componentDir);
      }
      let jobname = component.getJobnameForComponent(componentName, componentManifest);



      let listenAddress = '0.0.0.0';
      if (ZOWE_CONFIG.components[componentName].zowe?.network?.server?.listenAddresses) {
        listenAddress = ZOWE_CONFIG.components[componentName].zowe.network.server.listenAddresses[0];
      } else if (ZOWE_CONFIG.zowe?.network?.server?.listenAddresses) {
        listenAddress = ZOWE_CONFIG.zowe.network.server.listenAddresses[0];
      }
      common.printFormattedDebug(common.MSG_KEY, COMMAND_NAME, `${componentName}: Checking port ${port}`);
      
      //TODO this only works on z/OS, but configmgr also only works on z/OS, so at this time the limitation has not been exposed.
      if (jobname) {
        std.setenv('_BPX_JOBNAME', jobname);
        common.printFormattedDebug(common.MSG_KEY, COMMAND_NAME, `${componentName}: Checking port ${port}, jobname ${jobname}`);
      } else {
        common.printFormattedDebug(common.MSG_KEY, COMMAND_NAME, `${componentName}: Checking port ${port} with default jobname`);
      }
      
      let result = shell.execOutSync(bindUtilPath, '--host', listenAddress, '--port', port);
      if (jobname) {
        //restore
        std.setenv('_BPX_JOBNAME', myJobname);
      }
      if (result.rc) {
        failedCount++;
        if (result.out) {
          common.printDebug(result.out);
        }
        if (jobname) {
          common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `ZWEL0357E: ${componentName} Port ${port} not available for jobname ${jobname} or command failed.`);
        } else {
          common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `ZWEL0357E: ${componentName} Port ${port} not available or command failed.`);
        }
        hasErrors = true;
      } else if (result.out) {
        common.printDebug(result.out);
      }
    } else {
      common.printFormattedDebug(common.MSG_KEY, COMMAND_NAME, `${componentName}: Component has no port, skipped.`);
    }
  }
  if (!hasErrors) {
    common.printFormattedInfo(common.MSG_KEY, COMMAND_NAME, `Zowe port bind validation passed.`);
    return 0;
  } else if (!quitOnError) {
    common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `ZWEL0358E: ${failedCount} port bind validation(s) failed, review output for action items before running Zowe.`);
    return failedCount;
  } else {
    common.printFormattedError(common.MSG_KEY, COMMAND_NAME, `Port bind validation failed. This check can be dismissed with YAML value "zowe.launchScript.startupChecks.ports: warn"`);
    common.printErrorAndExit(`ZWEL0358E: ${failedCount} port bind validation(s) failed, review output for action items before running Zowe.`, undefined, 8);
    return failedCount;
  }
}
