/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as common from './common';
import * as shell from './shell';

export function validateZosmfHostAndPort(zosmfHost: string, zosmfPort: number, scheme:string='https', jobname?: string, warnOnly: boolean=false): boolean {
  if (!zosmfHost) {
    common.printError('z/OSMF host is not set.');
    return false;
  }
  if (!zosmfPort) {
    common.printError('z/OSMF port is not set.');
    return false;
  }
  let zosmfCheckPassed=true;

  let backupJobname = std.getenv('_BPX_JOBNAME');
  std.setenv('_BPX_JOBNAME', jobname);
  const execReturn = shell.execOutSync(`${std.getenv('ZWE_zowe_runtimeDirectory')}/bin/utils/curl`, `${scheme}://${zosmfHost}:${zosmfPort}/zosmf/info`, `-k`, `-H`, `X-CSRF-ZOSMF-HEADER: true`, `-w`, `%{http_code}`, `--max-time`, `10`, `-s`, `-o`, `/dev/null`);
  //restore jobname
  if (backupJobname) {
    std.setenv('_BPX_JOBNAME', backupJobname);
  } else {
    std.unsetenv('_BPX_JOBNAME');
  }
  if (execReturn.rc || !execReturn.out) {
    common.printError(`Warning: Could not validate if z/OSMF is available on '${scheme}://${zosmfHost}:${zosmfPort}/zosmf/info'. No response code from z/OSMF server.`);
    zosmfCheckPassed=false
  // RSU2512 -> running z/OSMF is returning 401
  } else if (['200', '401'].includes(execReturn.out) == false) {
    common.printError(`Could not contact z/OSMF on '${scheme}://${zosmfHost}:${zosmfPort}/zosmf/info' - ${execReturn.out}`);
    zosmfCheckPassed=false
  }
  
  if (zosmfCheckPassed) {
    common.printMessage(`Successfully checked z/OSMF is available on '${scheme}://${zosmfHost}:${zosmfPort}/zosmf/info' - ${execReturn.out}`);
  }
  return zosmfCheckPassed || warnOnly;
}
