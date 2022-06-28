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
import * as fakejq from '../../../../libs/fakejq';

export function execute(configPath:string, haInstance?: string) {
const ZOWE_CONFIG=config.getZoweConfig();

  if (haInstance && (!configPath.startsWith(`haInstances.${haInstance}.`))) {
    common.printMessage(fakejq.jqget(ZOWE_CONFIG, `.haInstances[${haInstance}].${configPath}`)); //TODO expand path
  } else {
    common.printMessage(fakejq.jqget(ZOWE_CONFIG, `.${configPath}`)); //TODO expand path
  }             
}
