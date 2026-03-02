/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import * as common from '@bin/libs/common';

export function assertEqualsStrict(val1, val2): number {
  if (val1 !== val2) {
    common.printMessage(`Expected values to be strictly equals:\n\t${JSON.stringify(val1)}\n\t${JSON.stringify(val2)}`);
    return 1;
  }
  return 0;
}

export function assertEquals(val1, val2) {
  if (val1 != val2) {
    throw new Error(`Expected values to be equal with type coercion:\n\t${JSON.stringify(val1)}\n\t${JSON.stringify(val2)}`);
  }
}
