/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html

  SPDX-License-Identifier: EPL-2.0

  Copyright Contributors to the Zowe Project.
*/

import * as stringLib from './string';

export function splitRuntimeToVariable(runtime: string): string {
    const runtimeArray = stringLib.splitStringByLength(runtime, 50);
    runtime = `SH ZWE_RD="${runtimeArray[0]}";\n`;
    for (let i = 1; i < runtimeArray.length; i++) {
        runtime += `ZWE_RD="\$\{ZWE_TMP\}${runtimeArray[i]}";\n`;
    }
    runtime += 'cd "${ZWE_TMP}";';
    return runtime;
}
