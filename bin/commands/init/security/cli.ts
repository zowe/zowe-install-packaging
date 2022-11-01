/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'std';
import * as index from './index';
import * as configmgr from '../../../libs/configmgr';

index.execute(std.getenv('ZWE_CLI_PARAMETER_SECURITY_DRY_RUN') == "true", std.getenv('ZWE_CLI_PARAMETER_IGNORE_SECURITY_FAILURES') == "true");

configmgr.cleanupTempDir();
