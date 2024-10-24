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

const COMPONENTS = {
    a: {
        title: 'Zowe API Mediation Layer (APIML)',
        urls: [
            { text: 'API Mediation Layer', link: 'https://docs.zowe.org/stable/troubleshoot/troubleshoot-apiml-error-codes' }
        ]
    },
    d: {
        title: 'Zowe Desktop and the App Server',
        urls: [
            { text: 'Application framework', link: 'https://docs.zowe.org/stable/troubleshoot/app-framework/appserver-error-codes' }
        ]
    },
    l: {
        title: 'Zowe Launcher and zwe',
        urls: [
            { text: 'Launcher', link: 'https://docs.zowe.org/stable/troubleshoot/launcher/launcher-error-codes' },
            { text: 'Launcher error codes', link: `https://github.com/zowe/launcher/blob/v${common.getZoweVersion().substring(0,1)}.x/master/src/msg.h`, git: true },
            { text: 'zwe', link: 'https://docs.zowe.org/stable/appendix/zwe_server_command_reference/zwe/' },
        ]
    },
    s: {
        title: 'Zowe Subsystem Services (ZSS) and Zowe Installation Services (ZIS)',
        urls: [
            { text: 'ZSS', link: 'https://docs.zowe.org/stable/troubleshoot/app-framework/zss-error-codes' },
            { text: 'ZIS', link: 'https://docs.zowe.org/stable/troubleshoot/app-framework/zis-error-codes' }
        ]
    }
}

function printComponent(component: any): void {
    common.printMessage(`\nThis code corresponds to the errors related to the ${component.title}.\n`);
    common.printMessage(`To find the description of this error code, refer to the:\n`);
    for (let url in component.urls) {
        let zoweDocFor = component.urls[url].git ? '' : 'Zowe documentation for ';
        common.printMessage(`  ${zoweDocFor}${component.urls[url].text}`);
        common.printMessage(`    ${component.urls[url].link}`);
    }
}

export function execute(): void {
    const errorCode = std.getenv('ZWE_CLI_PARAMETER_ERROR_CODE');
    if (/^[zZ][wW][eE][AaSsDdLl][A-Za-z]?[0-9]{3,4}[A-Za-z]$/.test(errorCode)) {
        const serverCode = errorCode.charAt(3).toLowerCase();
        if ('adls'.includes(serverCode)) {
            printComponent(COMPONENTS[serverCode]);
            common.printMessage(`\nYou may also explore reports from other users experiencing the same error by searching\nhttps://github.com/search?q=org%3Azowe+${errorCode}&type=discussions\n`);
        }
    } else {
        common.printErrorAndExit(`ZWEL0102E: Invalid parameter --error-code='${errorCode}'`, undefined, 102);
    }
}
