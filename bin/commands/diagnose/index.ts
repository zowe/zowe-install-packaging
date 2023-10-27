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

const THIS_CODE = "\nThis code corresponds to the errors related to the";
const FIND_DESC = "To find the description of this error code, refer to the:\n ";
const URL = {
    apiML: "https://docs.zowe.org/stable/troubleshoot/troubleshoot-apiml-error-codes",
    appFW : "https://docs.zowe.org/stable/troubleshoot/app-framework/appserver-error-codes",
    launcher: "https://docs.zowe.org/stable/troubleshoot/launcher/launcher-error-codes",
    launcherGit: "https://github.com/zowe/launcher/blob/v2.x/master/src/msg.h",
    zss: "https://docs.zowe.org/stable/troubleshoot/app-framework/zss-error-codes",
    zis: "https://docs.zowe.org/stable/troubleshoot/app-framework/zis-error-codes",
    zwe: "https://docs.zowe.org/stable/appendix/zwe_server_command_reference/zwe/"
}

function thisCodeCorrespondsTo(component: string){
    common.printMessage(`${THIS_CODE} ${component}.\n`);
    common.printMessage(`${FIND_DESC}`);
}

function printLinks(description: string, link: string){
    if (link.indexOf('github') > 0)
        common.printMessage(`  ${description}`)
    else 
    common.printMessage(`  Zowe documentation for ${description}`)
    common.printMessage(`    ${link}`);
}

export function execute() {
    const errorCode = std.getenv('ZWE_CLI_PARAMETER_ERROR_CODE');
    if (/^[zZ][wW][eE][AaSsDdLl][A-Za-z]?[0-9]{3,4}[A-Za-z]$/.test(errorCode)) {
        const serverCode = errorCode.charAt(3);
        if (serverCode.toLowerCase() === 'd') {
            thisCodeCorrespondsTo('ZOWE Desktop and the App Server');
            printLinks('Application framework', `${URL.appFW}`);
        }
        else if (serverCode.toLowerCase() === 's') {
            thisCodeCorrespondsTo('Zowe Subsystem Services (ZSS) and Zowe Installation Services (ZIS)');
            printLinks('ZSS', `${URL.zss}`);
            printLinks('ZIS', `${URL.zis}`);
        }
        else if (serverCode.toLowerCase() === 'a') {
            thisCodeCorrespondsTo('Zowe API Mediation Layer (APIML)');
            printLinks('API Mediation Layer', `${URL.apiML}`);
        }
        else if (serverCode.toLowerCase() === 'l') {
            thisCodeCorrespondsTo('Zowe Launcher and ZWE');
            printLinks('Launcher', `${URL.launcher}`);
            printLinks('Launcher error codes', `${URL.launcherGit}`);
            printLinks('ZWE', `${URL.zwe}`);
        }
        common.printMessage(`\nYou may also explore reports from other users experiencing the same error by searching\nhttps://github.com/search?q=org%3Azowe+${errorCode}&type=discussions\n`);
    }
    else {
        common.printErrorAndExit(`ZWEL0102E: Invalid parameter --error-code='${errorCode}'`, undefined, 102);
    }
}
