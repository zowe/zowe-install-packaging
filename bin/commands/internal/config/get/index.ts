/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as config from '../../../../libs/config';

export function execute(configPath:string, haInstance?: string) {
const ZOWE_CONFIG=config.getZoweConfig();

  if (haInstance && (!configPath.startsWith(`haInstances.${haInstance}.`)) {
    console.log(ZOWE_CONFIG.haInstances[haInstance].); //TODO expand path
  } else {
    console.log(ZOWE_CONFIG.); //TODO expand path
  }             
}
