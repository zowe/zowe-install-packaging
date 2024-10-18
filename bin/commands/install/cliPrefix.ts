/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as index from './index';

const install = {
  prefix: std.getenv("ZWE_CLI_PARAMETER_DATASET_PREFIX"),
  yaml: false,
  runtime: undefined,
  jclHeader: undefined
}

index.execute(install);