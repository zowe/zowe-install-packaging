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
import * as zos from 'zos';
import * as common from '../../../../libs/common';
import * as stringlib from '../../../../libs/string';
import * as shell from '../../../../libs/shell';
import * as sys from '../../../../libs/sys';
import * as config from '../../../../libs/config';

//# This command prepares everything needed to start Zowe.

// Extra preparations for running in container
// - link component runtime under zowe <runtime>/components
// - `commands.configureInstance` is deprecated in v2
function prepareRunningInContainer() {
  // gracefully shutdown all processes
  common.printFormattedDebug("ZWELS", "zwe-internal-start-prepare,prepare_running_in_container", "Register SIGTERM handler for graceful shutdown.");
  os.signal(os.SIGTERM, sys.gracefullyShutdown());

  
}

// Validation
common.requireZoweYaml();

// Read job name and validate
//const zoweConfig = config.getZoweConfig();
