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
import * as json from '../../../../libs/json';

export function execute(configPath:string, newValue: any, haInstance?: string, valueAsString?: boolean) {
  common.requireZoweYaml();
  const configFiles=std.getenv('ZWE_PRIVATE_CONFIG_ORIG');
  const ZOWE_CONFIG=config.getZoweConfig();
  let rc = 0;

  if (!valueAsString) {
    if (['true', 'false'].includes(newValue.toLowerCase())) {
      newValue = newValue.toLowerCase() == 'true';
    } else if (!isNaN(Number(newValue))) {
      newValue = Number(newValue);
    }
  }

  if (haInstance) {
    haInstance=config.sanitizeHaInstanceId();
    if (ZOWE_CONFIG.haInstances) {
      for (const haInstanceID in ZOWE_CONFIG.haInstances) {
        if (haInstanceID.toLowerCase() == haInstance) {
          haInstance = haInstanceID;
        }
      }
    }
    if (!configPath.startsWith(`haInstances.${haInstance}.`)) {
      rc = json.updateZoweYaml(configFiles, `haInstances.${haInstance}.${configPath}`, newValue);
    } else {
      rc = json.updateZoweYaml(configFiles, '.'+configPath, newValue);
    }
  } else {
    rc = json.updateZoweYaml(configFiles, '.'+configPath, newValue);
  }
  std.exit(rc);
}
