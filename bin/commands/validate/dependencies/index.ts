/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as common from '../../../libs/common';
import * as component from '../../../libs/component';
import * as javaCI from '../../../libs/java_ci';
import * as node from '../../../libs/node';
import * as zoslib from '../../../libs/zos';


//TODO this file basically duplicates the checks that zwe internal start prepare does for node & java
//consider removing that code in favor of this;
export function execute(quitOnError?: boolean) {
  const enabledComponents=component.getEnabledComponents();
  let hasErrors = false;
  if (enabledComponents.includes('app-server')) {
    let nodeOk = node.validateNodeHome();
    if (!nodeOk) {
      hasErrors = true;
      common.printFormattedError('ZWELS', "zwe-validate-dependencies", `NodeJS validation failed.`);
    }
  }

  //TODO this should be a manifest parameter that you require java, not a hardcoded list. What if extensions require it?
  if (enabledComponents.includes('gateway') || enabledComponents.includes('zaas') || enabledComponents.includes('discovery') || enabledComponents.includes('api-catalog') || enabledComponents.includes('caching-service')) {
    let javaOk = javaCI.validateJavaHome();
    if (!javaOk) {
      hasErrors = true;
      common.printFormattedError('ZWELS', "zwe-validate-dependencies", `Java validation failed.`);
    }
  }

  let zosVersion = zoslib.formatZosVersion('{major}.{minor}').split('.');
  common.printFormattedInfo(`ZWELS`, `zwe-validate-dependencies`, `z/OS version detected: ${zosVersion}`);
  let zosMajor = Number(zosVersion[0]);
  let zosMinor = Number(zosVersion[1]);
  if (zosMajor < 3 && zosMinor < 4) {
    common.printFormattedError(`ZWELS`, `zwe-validate-dependencies`, `z/OS version lower than the minimum supported version, z/OS  2.4`);
    hasErrors = true;
  } else if (zosMajor == 3 && zosMinor > 1) {
    common.printFormattedInfo(`ZWELS`, `zwe-validate-dependencies`, `z/OS version higher than the latest known working version for Zowe, z/OS 3.1`);
  } else if (zosMajor > 3) {
    common.printFormattedInfo(`ZWELS`, `zwe-validate-dependencies`, `z/OS version higher than the latest known working version for Zowe, z/OS 3.1`);
  }

  if (!hasErrors) {
    common.printFormattedInfo(`ZWELS`, `zwe-validate-dependencies`, `Zowe dependency validation passed.`);
  } else if (!quitOnError) {
    common.printFormattedError(`ZWELS`, `zwe-validate-dependencies`, `Zowe dependency validation failed, review output for action items before running Zowe.`);
  } else {
    common.printErrorAndExit(`Zowe dependency validation failed, review output for action items before running Zowe.`, null, 8);
  }
}
