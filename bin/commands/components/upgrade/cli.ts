/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as index from '../install/index';
import * as std from 'cm_std';
import * as configmgr from '../../../libs/configmgr';

const skipEnable = true; //because its already done.
const upgrade = true; //tell install.ts that its upgrading instead
index.execute(std.getenv('ZWE_CLI_PARAMETER_COMPONENT_FILE'), std.getenv('ZWE_CLI_PARAMETER_AUTO_ENCODING'), skipEnable, std.getenv('ZWE_CLI_PARAMETER_HANDLER'), std.getenv('ZWE_CLI_PARAMETER_REGISTRY'), (std.getenv('ZWE_CLI_PARAMETER_DRY_RUN') === 'true'), upgrade);

configmgr.cleanupTempDir();
