/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as zoslib from '../../libs/zos';
import * as common from '../../libs/common';
import * as stringlib from '../../libs/string';
import * as shell from '../../libs/shell';
import * as config from '../../libs/config';

export function execute() {
  common.printLevel0Message('Stopping zowe');

  // Validation
  common.requireZoweYaml();

  // read Zowe STC name and apply default value
  const zoweConfig = config.getZoweConfig();
  let securityStcsZowe = zoweConfig.zowe.setup?.security?.stcs?.zowe;
  if (!securityStcsZowe) {
    securityStcsZowe=std.getenv('ZWE_PRIVATE_DEFAULT_ZOWE_STC');
  }
  // read job name and apply default value
  let jobname: string;
  config.sanitizeHaInstanceId();
  const haInstance=std.getenv('ZWE_CLI_PARAMETER_HA_INSTANCE');

  if (haInstance && zoweConfig.haInstances && zoweConfig.haInstances[haInstance]) {
    jobname=zoweConfig.haInstances[haInstance].zowe?.job?.name;
  }
  if (!jobname) {
    jobname = zoweConfig.zowe.job?.name;
  }
  if (!jobname) {
    jobname=securityStcsZowe
  }

  // read SYSNAME if --ha-instance is specified
  let routeSysname:string;
  if (haInstance && zoweConfig.haInstances && zoweConfig.haInstances[haInstance]) {
    routeSysname = zoweConfig.haInstances[haInstance]?.sysname;
  }

  // start job
  let cmd=`P ${jobname}`
  if (routeSysname) {
    cmd=`RO ${routeSysname},${cmd}`
  }
  const shellReturn = zoslib.operatorCommand(cmd);
  if (shellReturn.rc != 0) {
    common.printErrorAndExit(`Error ZWEL0166E: Failed to stop ${jobname}: exit code ${shellReturn.rc}.`, undefined, 166);
  } else {
    let errorMessage = shellReturn.out;
    if (shellReturn.out) {
      const errorResult = shell.execOutSync('sh', '-c', `echo "${shellReturn.out}" | awk "/-P ${jobname}/{x=NR+1;next}(NR<=x){print}" | sed "s/^\\([^ ]\\+\\) \\+\\([^ ]\\+\\) \\+\\([^ ]\\+\\) \\+\\(.\\+\\)\\$/\\4/"`);
      errorMessage = errorResult.out;
    }
    if (errorMessage) {
      common.printErrorAndExit(`Error ZWEL0166E: Failed to stop ${securityStcsZowe}: ${stringlib.trim(errorMessage)}.`, undefined, 166);
    }
}


  // exit message
  common.printLevel1Message(`Terminate command on job ${jobname} is sent successfully. Please check job log for details.`);
}
