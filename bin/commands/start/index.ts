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
  common.printLevel0Message('Starting zowe');

  // Validation
  common.requireZoweYaml();

  const zoweConfig = config.getZoweConfig();
  // zowe.job.name and zowe.setup.security.stcs.zowe defined in defaults
  // And rejected by schema if user defines null/empty => always defined
  const jobname = zoweConfig.zowe.job.name;
  const securityStcsZowe = zoweConfig.zowe.setup.security.stcs.zowe;

  let routeSysname: string;

  config.sanitizeHaInstanceId();
  const haInstance=std.getenv('ZWE_CLI_PARAMETER_HA_INSTANCE');
  if (haInstance && zoweConfig.haInstances && zoweConfig.haInstances[haInstance]) {
    routeSysname = zoweConfig.haInstances[haInstance]?.sysname;
  }

  // Start job
  let cmd=`S ${securityStcsZowe}`;
  if (haInstance) {
    cmd+=`,HAINST=${haInstance}`;
  }
  cmd+=`,JOBNAME=${jobname}`;
  if (routeSysname) {
    cmd=`RO ${routeSysname},${cmd}`;
  }

  const operCmdReturn = zoslib.operatorCommand(cmd);
  if (operCmdReturn.rc != 0) {
    const errorExplanation = operCmdReturn.rc == zoslib.OPER_CMD_NO_SDSF ? operCmdReturn.out : `exit code ${operCmdReturn.rc}`;
    common.printError(`Error ZWEL0165E: Failed to start ${securityStcsZowe}: ${errorExplanation}.`);
    if (operCmdReturn.rc == zoslib.OPER_CMD_NO_SDSF) {
      common.printMessage(`Use following operator command to start Zowe Launcher manually: ${cmd}`);
    }
    std.exit(165);
  }
  else {
    //TODO handle awk and set patterns here
    let errorMessage = operCmdReturn.out;
    if (operCmdReturn.out) {
      const errorResult = shell.execOutSync('sh', '-c', `echo "${operCmdReturn.out}" | awk "/-S ${securityStcsZowe}/{x=NR+1;next}(NR<=x){print}" | sed "s/^\\([^ ]\\+\\) \\+\\([^ ]\\+\\) \\+\\([^ ]\\+\\) \\+\\(.\\+\\)\\$/\\4/"`);
      errorMessage = errorResult.out;
    }
    if (errorMessage) {
      common.printErrorAndExit(`Error ZWEL0165E: Failed to start ${securityStcsZowe}: ${stringlib.trim(errorMessage)}.`, undefined, 165);
    }
  }

  // Exit message
  common.printLevel1Message(`Job ${jobname?jobname:securityStcsZowe} is started successfully.`);
}
