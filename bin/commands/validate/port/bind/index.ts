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

export function execute(quitOnError?: boolean, componentName?: string) {
  let enabledComponents = componentName ? [componentName] : component.getEnabledComponents();
  let hasErrors = false;
  const ZOWE_CONFIG = config.getZoweConfig();
  let bindUtilPath = ZOWE_CONFIG.zowe.runtimeDirectory;
  if (!bindUtilPath.endsWith('/')) {
    bindUtilPath += '/';
  }
  bindUtilPath += 'bin/utils/bind-test';

  let myJobname = std.getenv('_BPX_JOBNAME');

  for (let i = 0; i < enabledComponents.length; i++) {
    let componentName = enabledComponents[i];
    let port = ZOWE_CONFIG.components[componentName].port;
    if (component.isComponentInAPIMLModulith(componentName)) {
      if (componentName == 'gateway' && !port) {
        port = ZOWE_CONFIG.components.apiml.port;
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

      //TODO this only works on z/OS, but configmgr also only works on z/OS, so at this time the limitation has not been exposed.
      if (jobname) {
        std.setenv('_BPX_JOBNAME', jobname);
      }
      let result = shell.execSync(bindUtilPath, '--host', listenAddress, '--port', port);
      if (jobname) {
        //restore
        std.setenv('_BPX_JOBNAME', myJobname);
      }
      if (result.rc) {
        common.printFormattedError(`ZWELS`, `zwe-validate-port-available`, `${componentName} port ${port} not available or command failed.`);
        hasErrors = true;
      }

    }
  }
  if (!hasErrors) {
    common.printFormattedInfo(`ZWELS`, `zwe-validate-port-available`, `Zowe port bind validation passed.`);
  } else if (!quitOnError) {
    common.printFormattedError(`ZWELS`, `zwe-validate-port-available`, `Zowe port bind validation failed, review output for action items before running Zowe.`);
  } else {
    common.printErrorAndExit(`Zowe port bind validation failed, review output for action items before running Zowe.`, null, 8);
  }
}
