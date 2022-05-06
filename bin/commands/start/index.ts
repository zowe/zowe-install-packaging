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
import * as common from '../../libs/common';
import * as stringlib from '../../libs/string';
import * as shell from '../../libs/shell';
import * as config from '../../libs/config';


common.printLevel0Message('Starting zowe');

// Validation
common.requireZoweYaml();

// Read job name and validate
const zoweConfig = config.getZoweConfig();
const jobname = zoweConfig.zowe.job.name;
let securityStcsZowe = zoweConfig.zowe.setup.security.stcs.zowe;
if (!securityStcsZowe) {
  //TODO defaults should be stored in default yaml, not out of thin air
  securityStcsZowe=std.getenv('ZWE_PRIVATE_DEFAULT_ZOWE_STC');
}
let routeSysname;

sanitizeHaInstanceId();
const haInstance=std.getenv('ZWE_CLI_PARAMETER_HA_INSTANCE');
if (haInstance) {
  routeSysname=zoweConfig.haInstances[haInstance].sysname;
}

// Start job
let cmd=`S ${securityStcsZowe}`;
if (haInstance) {
  cmd+=`,HAINST=${haInstance}`;
}
if (jobname) {
  cmd+=`,JOBNAME=${jobname}`;
}
if (routeSysname) {
  cmd=`RO ${routeSysname},${cmd}`;
}

const shellReturn = operatorCommand(cmd);
if (shellReturn.rc) {
  common.printErrorAndExit(`Error ZWEL0165E: Failed to start ${securityStcsZowe}: exit code ${shellReturn.rc}.`, undefined, 165);
} else {
  //TODO handle awk and set patterns here
  let errorMessage;//stringlib.trim(shellReturn.out | awk "/-S ${security_stcs_zowe}/{x=NR+1;next}(NR<=x){print}" | sed "s/^\([^ ]\+\) \+\([^ ]\+\) \+\([^ ]\+\) \+\(.\+\)\$/\4/");
  if (errorMessage) {
    common.printErrorAndExit(`Error ZWEL0165E: Failed to start ${securityStcsZowe}: ${errorMessage}.`, undefined, 165);
  }
}

// Exit message
common.printLevel1Message(`Job ${jobname?jobname:securityStcsZowe} is started successfully.`);
