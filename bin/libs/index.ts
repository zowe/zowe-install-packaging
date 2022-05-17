/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'std';
import * as os from 'os';

if (!std.getenv("ZWE_zowe_runtimeDirectory")) {
  std.err.printf("Error ZWEL0101E: ZWE_zowe_runtimeDirectory is not defined.\n");
  std.exit(101);
}

