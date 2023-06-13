/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as index from './index';
import * as std from 'cm_std';
import * as os from 'cm_os';
import * as configmgr from '../../../libs/configmgr';

const upgrade = false; //would be true for upgrade.ts

index.execute(std.getenv('ZWE_CLI_PARAMETER_COMPONENT_FILE'), std.getenv('ZWE_CLI_PARAMETER_AUTO_ENCODING'), (std.getenv('ZWE_CLI_PARAMETER_SKIP_ENABLE') === 'true'), std.getenv('ZWE_CLI_PARAMETER_HANDLER'), std.getenv('ZWE_CLI_PARAMETER_REGISTRY'), (std.getenv('ZWE_CLI_PARAMETER_DRY_RUN') === 'true'), upgrade);

configmgr.cleanupTempDir();