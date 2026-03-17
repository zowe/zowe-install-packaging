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

export function execute(): void {
  common.printFormattedInfo('ZWELS', COMMAND_NAME, 'Validating runtime dependencies...'); 

  javaCmd.execute(false);
  nodeCmd.execute(false);
}
