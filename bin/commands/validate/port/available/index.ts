/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as common from '../../../../libs/common';
import * as config from '../../../../libs/config';
import * as component from '../../../../libs/component';
import * as network from '../../../../libs/network';


//TODO this file basically duplicates the checks that zwe internal start prepare does for node & java
//consider removing that code in favor of this;
export function execute(quitOnError?: boolean) {
  const enabledComponents=component.getEnabledComponents();
  let hasErrors = false;
  const ZOWE_CONFIG=config.getZoweConfig();
  enabledComponents.forEach((component)=> {
    let port = ZOWE_CONFIG.components[component].port;
    if (port) {
      if (network.isPortAvailable(port)) {
        common.printFormattedInfo(`ZWELS`, `zwe-validate-port-available`, `${component} port ${port} available.`);
      } else {
        common.printFormattedError(`ZWELS`, `zwe-validate-port-available`, `${component} port ${port} not available or command failed.`);
        hasErrors = true;
      }
    }
  });
  if (!hasErrors) {
    common.printFormattedInfo(`ZWELS`, `zwe-validate-port-available`, `Zowe port availability validation passed.`);
  } else if (!quitOnError) {
    common.printFormattedError(`ZWELS`, `zwe-validate-port-available`, `Zowe port availability validation failed, review output for action items before running Zowe.`);
  } else {
    common.printErrorAndExit(`Zowe port availability validation failed, review output for action items before running Zowe.`, null, 8);
  }
}
