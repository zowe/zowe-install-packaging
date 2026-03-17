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
import * as java from '../../../../libs/java';
import * as javaCI from '../../../../libs/java_ci';

const COMMAND_NAME = 'zwe-validate-dependencies-java';

const JAVA_DEPENDENT_COMPONENTS = ['apiml', 'gateway', 'discovery', 'zaas', 'api-catalog', 'caching-service'];

export function execute(quitOnError: boolean = true): void {
  common.requireZoweYaml();

  const ZOWE_CONFIG = config.getZoweConfig();

  const enabledJavaComponents = JAVA_DEPENDENT_COMPONENTS.filter(
    (name) => ZOWE_CONFIG?.components?.[name]?.enabled === true
  );

  common.printFormattedInfo('ZWELS', COMMAND_NAME, `Validating Java dependency (required: >= ${javaCI.JAVA_MIN_VERSION}, <= ${javaCI.JAVA_MAX_VERSION})...`);

  java.requireJava();

  const result = javaCI.validateJavaHome(undefined, !quitOnError);
  if (!result) {
    const baseMsg = `Java version validation failed. Ensure Java >= ${javaCI.JAVA_MIN_VERSION} and <= ${javaCI.JAVA_MAX_VERSION} is installed.`;
    let msg: string = baseMsg;
    if (enabledJavaComponents.length > 0) {
      msg = `${baseMsg} Java is required for the following enabled component(s): ${enabledJavaComponents.join(', ')}.`;
    } else {
      msg = `${baseMsg} Note: none of the Java-dependent components (${JAVA_DEPENDENT_COMPONENTS.join(', ')}) are currently enabled, so Java may not be required. ` +
        `If Java is not needed, set 'zowe.launchScript.startupChecks.java' to 'warn' or 'disabled' in your zowe.yaml to bypass this error.`;
    }
    if (quitOnError) {
      common.printFormattedError('ZWELS', COMMAND_NAME, `ZWEL0360E: ${msg}`);
      std.exit(1);
    } else {
      common.printFormattedWarn('ZWELS', COMMAND_NAME, `ZWEL0360W: ${msg}`);
    }
  } else {
    if (enabledJavaComponents.length > 0) {
      common.printFormattedInfo('ZWELS', COMMAND_NAME, `Java dependency check passed. Required by enabled component(s): ${enabledJavaComponents.join(', ')}.`);
    } else {
      common.printFormattedInfo('ZWELS', COMMAND_NAME, 'Java dependency check passed.');
    }
  }
}
