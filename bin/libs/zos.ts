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
import * as stringlib from './string';

export function tsoCommand(...args:string[]): { rc: number, out: string } {
  let message="tsocmd "+args.join(' ');
  common.printDebug('- '+message);
  //we echo at the end to avoid a configmgr quirk where trying to read stdout when empty can hang waiting for bytes
  const result = shell.execOutSync('sh', '-c', `${message} 2>&1 && echo '.'`);
  if (result.rc == 0) {
    common.printDebug("  * Succeeded");
    common.printTrace(`  * Exit code: ${result.rc}`);
    common.printTrace("  * Output:");
    if (result.out) {
      common.printTrace(stringlib.paddingLeft(result.out, "    "));
    }
  } else {
    common.printDebug("  * Failed");
    common.printError(`  * Exit code: ${result.rc}`);
    common.printError("  * Output:");
    if (result.out) {
      common.printError(stringlib.paddingLeft(result.out, "    "));
    }
  }
  //we strip the '.' we added above
  return { rc: result.rc, out: result.out ? result.out.substring(0, result.out.length-1) : '' };
}

export function operatorCommand(command: string): { rc: number, out: string } {
  const opercmd=std.getenv('ZWE_zowe_runtimeDirectory')+'/bin/utils/opercmd.rex';

  let message=`- opercmd ${command}`;
  common.printDebug(message);
  //we echo at the end to avoid a configmgr quirk where trying to read stdout when empty can hang waiting for bytes
  const result = shell.execOutSync('sh', '-c', `${opercmd} "${command}" 2>&1 && echo '.'`);
  if (result.rc == 0) {
    common.printDebug("  * Succeeded");
    common.printTrace(`  * Exit code: ${result.rc}`);
    common.printTrace("  * Output:");
    if (result.out) {
      common.printTrace(stringlib.paddingLeft(result.out, "    "));
    }
  } else {
    common.printDebug("  * Failed");
    common.printError(`  * Exit code: ${result.rc}`);
    common.printError("  * Output:");
    if (result.out) {
      common.printError(stringlib.paddingLeft(result.out, "    "));
    }
  }
  //we strip the '.' we added above
  return { rc: result.rc, out: result.out ? result.out.substring(0, result.out.length-1) : '' };
}
