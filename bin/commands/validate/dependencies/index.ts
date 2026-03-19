/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html

  SPDX-License-Identifier: EPL-2.0

  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as common from '../../../libs/common';
import * as config from '../../../libs/config';
import * as javaCmd from './java/index';
import * as nodeCmd from './node/index';

const COMMAND_NAME = 'zwe-validate-dependencies';

function resolveQuitOnError(checkKey: string): boolean | undefined {
  const ZOWE_CONFIG = config.getZoweConfig();
  const startupChecks = ZOWE_CONFIG?.zowe?.launchScript?.startupChecks as any;
  const level: string = (startupChecks?.[checkKey]) || (startupChecks?.default) || 'exit';
  if (level === 'disabled') return undefined;
  return level !== 'warn';
}

export function execute(): void {
  common.printFormattedInfo('ZWELS', COMMAND_NAME, 'Validating runtime dependencies...');

  const javaGood = javaCmd.execute(false, false);
  const nodeGood = nodeCmd.execute(false, false);

  common.printFormattedInfo('ZWELS', COMMAND_NAME, 'Runtime dependency validation complete.');
  if (!javaGood || !nodeGood) {
    std.exit(1);
  }
}
