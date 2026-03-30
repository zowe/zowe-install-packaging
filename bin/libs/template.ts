/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as xplatform from 'xplatform';

import * as common from './common';
import * as zosDs from './zos-dataset';

export function resolveString(templateString: string, data: any): string | undefined {
    common.printTrace(` - resolveString:\n${templateString}\n`);
    const template = new Function('return `' + templateString + '`;');
    if (templateString == undefined || templateString == null) {
        return undefined;
    }
    return template.call(data);
}

export function resolveFile(file: string, data: any): string | undefined {
    common.printTrace(` - resolveFile "${file}"`);
    const fileContent = xplatform.loadFileUTF8(file, xplatform.AUTO_DETECT);
    if (fileContent == undefined || fileContent == null) {
        return undefined;
    }
    return resolveString(fileContent, data);
}

export function resolveMember(dataset: string, data: any): string | undefined {
    common.printTrace(` - resolveMember "${dataset}"`);
    const memberContent = zosDs.readMember(dataset);
    if (memberContent == undefined || memberContent == null) {
        return undefined;
    }
    return resolveString(memberContent, data);
}
