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
import * as fakejq from '../../../../libs/fakejq';

export function execute(configPath:string, haInstance?: string) {
  if ((configPath.endsWith('.') && configPath.length != 1)
      || (configPath.indexOf('..') != -1)) {
    common.printErrorAndExit(`Error ZWEL0303E: Invalid config path syntax for ${configPath}. Get only supports single period delimiters between values.`, undefined, 303);
  }
  common.requireZoweYaml();
  const spaces = std.getenv('ZWE_CLI_PARAMETER_FORMAT') == 'true' ? 2 : 0;
  const ZOWE_CONFIG=config.getZoweConfig();
  let output;
  
  if (haInstance && ZOWE_CONFIG.haInstances) {
    haInstance = config.sanitizeHaInstanceId();
    for (const haInstanceID in ZOWE_CONFIG.haInstances) {    
      if (haInstanceID.toLowerCase() == haInstance) {
        haInstance = haInstanceID;
      }
    }
  }

  if (haInstance && (!configPath.startsWith(`haInstances.${haInstance}.`))) {
    output=fakejq.jqget(ZOWE_CONFIG, `.haInstances[${haInstance}].${configPath}`); //TODO expand path
    if (!output) { //if the instance doesnt specify this config, we'll fallback to the base config.
      output=fakejq.jqget(ZOWE_CONFIG, `.${configPath}`); //TODO expand path
    }
  } else {
    output=fakejq.jqget(ZOWE_CONFIG, `.${configPath}`); //TODO expand path
  }
  if (output===undefined) {
    output = '';
  }
  if (Array.isArray(output)) {
    output.forEach((line)=> {
      if (typeof line != 'object') {
        common.printMessage(line);
      } else {
        common.printMessage(JSON.stringify(line, null, spaces));
      }
    });
  } else {
    if (typeof output != 'object') {
      common.printMessage(output);
    } else {
      common.printMessage(JSON.stringify(output, null, spaces));
    }
  }
}
