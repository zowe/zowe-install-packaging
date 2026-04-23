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

/*
    * This module provides functions to resolve template strings, files, and data sets.
    * Template strings can contain variables in the form of ${this.variable} which will be replaced with corresponding values from the provided data object.
    * Template files and data sets are read and their content is processed as template strings.
    * The escape parameter allows for escaping special characters in the template string to ensure correct processing.
    * The default value for escape is true to handle special characters properly.
*/

export function resolveString(templateString: string, data: any, escape: boolean = true): string {
    if (templateString == undefined || templateString == null) {
        common.printErrorAndExit(`Error ZWEL0327E: Failed to read template string 'undefined' - no string defined.`, undefined, 327);
    }
    if (escape) {
        templateString = templateString.replace(/\\/g, '\\\\').replace(/`/g, '\\`');;
    }
    common.printTrace(` - template.resolveString:\n${templateString}\n`);
    const template = new Function('return `' + templateString + '`;');
    return template.call(data);
}

export function resolveFile(file: string, data: any, escape: boolean = true): string {
    common.printTrace(` - template.resolveFile "${file}"`);
    let fileContent = undefined;
    try {
        fileContent = xplatform.loadFileUTF8(file, xplatform.AUTO_DETECT);
    } catch (err) {
        common.printErrorAndExit(`Error ZWEL0327E: Failed to read template ${file} - ${err}.`, undefined, 327);
    }
    return resolveString(fileContent, data, escape);
}

export function resolveMember(dataset: string, data: any, escape: boolean = true): string {
    common.printTrace(` - template.resolveMember "${dataset}"`);
    const memberContent = zosDs.readMember(dataset);
    if (memberContent == undefined || memberContent == null) {
        common.printErrorAndExit(`Error ZWEL0327E: Failed to read template ${dataset} - no content.`, undefined, 327);
    }
    return resolveString(memberContent, data, escape);
}
