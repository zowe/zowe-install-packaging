/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'std';
import * as common from '../../../../libs/common';
import * as config from '../../../../libs/config';
import * as json from '../../../../libs/json';
import * as fakejq from '../../../../libs/fakejq';

export function execute(configPath:string, newValue: any, haInstance?: string) {
  common.requireZoweYaml();
  const configFiles=std.getenv('ZWE_CLI_PARAMETER_CONFIG');
  const ZOWE_CONFIG=config.getZoweConfig();
  let output;
  if (haInstance) {
    haInstance=config.sanitizeHaInstanceId();
    if (!configPath.startsWith(`haInstances.${haInstance}.`)) {
      json.updateZoweYaml(configFiles, `haInstances.${haInstance}.${configPath}`, newValue);
    } else {
      json.updateZoweYaml(configFiles, '.'+configPath, newValue);
    }
  } else {
    json.updateZoweYaml(configFiles, '.'+configPath, newValue);
  }
}

