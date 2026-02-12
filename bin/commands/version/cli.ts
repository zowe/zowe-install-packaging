/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as index from './index';

// scriptArgs is an array of arguments used to execute this script from index.sh
// [0] ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr
// [1] -script
// [2] "${ZWE_zowe_runtimeDirectory}/bin/commands/version/cli.js"
// [3] "${zoweRuntime}"

index.execute(scriptArgs[3]);
