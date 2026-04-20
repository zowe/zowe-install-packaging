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
import * as node from '../../../../libs/node';

const COMMAND_NAME = 'zwe-validate-dependencies-node';

export function execute(quitOnError: boolean = true): boolean|void {
  common.requireZoweYaml();

  const ZOWE_CONFIG = config.getZoweConfig();

  const appServerEnabled = ZOWE_CONFIG?.components?.['app-server']?.enabled === true;

  common.printFormattedInfo('ZWELS', COMMAND_NAME, `Validating Node.js dependency (required: >= ${node.NODE_MIN_VERSION}, <= ${node.NODE_MAX_VERSION})...`);

  node.requireNode();
  
  const nodeHome = ZOWE_CONFIG?.node?.home;
  const result = node.validateNodeHome(nodeHome, false, false);
  if (!result) {
    const baseMsg = `Node.js version validation failed. Ensure Node.js >= ${node.NODE_MIN_VERSION} and <= ${node.NODE_MAX_VERSION} is used wth Zowe.`;
    let msg: string;
    if (appServerEnabled) {
      msg = `${baseMsg} Node.js is required for app-server functionality.`;
    } else {
      msg = `${baseMsg} Note: app-server is not enabled, so Node.js may not be required. ` +
        `If Node.js is not needed, set 'zowe.launchScript.startupChecks.nodeMin' and 'zowe.launchScript.startupChecks.nodeMax' to 'warn' or 'disabled' in your zowe.yaml to bypass this error.`;
    }
    common.printFormattedError('ZWELS', COMMAND_NAME, `ZWEL0361E: ${msg}`);
    if (quitOnError) {
      std.exit(1);
    } else {
      return false;
    }
  } else {
    common.printFormattedInfo('ZWELS', COMMAND_NAME, 'Node.js dependency check passed.');
    return true;
  }
}
