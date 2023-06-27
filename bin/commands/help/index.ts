/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as common from '../../libs/common';

export function execute() {
  const errorCode: string = std.getenv('ZWE_CLI_PARAMETER_ERROR_CODE');

  const serverCode: string = errorCode.charAt(3);

  if (/^[zZ][wW][eE][AaSsDdLl][A-Za-z]?[0-9]{3,4}[A-Za-z]$/.test(errorCode)) {
    if (serverCode.toLowerCase() === 'd') {
      common.printMessage("This code corresponds to the errors related to the ZOWE Desktop and the App Server.");
      common.printMessage("To find the description of this error code, refer to the Zowe documentation at https://github.com/zowe/docs-site/blob/master/docs/troubleshoot/app-framework/appserver-error-codes.md");
    } else if (serverCode.toLowerCase() === 's') {
      common.printMessage("This code corresponds to the errors related to the Zowe Subsystem Services (ZSS) and Zowe Installation Services (ZIS)");
      common.printMessage("To find the description of this error code, refer to the Zowe documentation for ZSS at https://docs.zowe.org/stable/troubleshoot/app-framework/zss-error-codes and for ZIS at https://github.com/zowe/docs-site/blob/master/docs/troubleshoot/app-framework/zis-error-codes.md");
    } else if (serverCode.toLowerCase() === 'a') {
      common.printMessage("This code corresponds to the errors related to the Zowe API Mediation Layer (APIML).");
      common.printMessage("To find the description of this error code, refer to the Zowe documentation at https://docs.zowe.org/stable/troubleshoot/troubleshoot-apiml-error-codes");
    } else if (serverCode.toLowerCase() === 'l') {
      common.printMessage("This code corresponds to the errors related to the Zowe Launcher and ZWE");
      common.printMessage("To find the description of this error code, refer to the Zowe documentation for the Launcher at https://docs.zowe.org/stable/troubleshoot/launcher/launcher-error-codes and https://github.com/zowe/launcher/blob/v2.x/master/src/msg.h, and for ZWE at https://docs.zowe.org/stable/appendix/zwe_server_command_reference/zwe/");
    }
    common.printMessage(`You may also explore reports from other users experiencing the same error by searching here https://github.com/search?q=org%3Azowe+${errorCode}&type=discussions`)
  } else {
    common.printErrorAndExit("Invalid Error Code", undefined, 102);
  }
}
