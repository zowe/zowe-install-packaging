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
import * as zos from 'zos';

export function tsoCommand(...args:string[]): { rc: number, out: string } {
  let message = "tsocmd " + '"' + args.join(' ') + '"';
  common.printDebug('- '+message);
  //we echo at the end to avoid a configmgr quirk where trying to read stdout when empty can hang waiting for bytes
  const result = shell.execOutSync('sh', '-c', `${message} 2>&1 && echo '.'`);
  if (result.rc == 0) {
    common.printDebug("  * Succeeded");
    common.printTrace(`  * Exit code: ${result.rc}`);
    common.printTrace("  * Output:");
    if (result.out) {
      result.out = result.out.substring(0, result.out.length - 1);
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
  return { rc: result.rc, out: result.out ? result.out : '' };
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

export function formatZosVersion(format?: string, versionNumber?: string | number): string {
  const ZOS_VERS = {
    'Z1030100': { 'osname': 'z/OS', 'hbb': 'HBB77E0', 'major': '3', 'minor': '1' },
    'Z1020500': { 'osname': 'z/OS', 'hbb': 'HBB77D0', 'major': '2', 'minor': '5' },
    'Z1020400': { 'osname': 'z/OS', 'hbb': 'HBB77C0', 'major': '2', 'minor': '4' },
    'Z1020300': { 'osname': 'z/OS', 'hbb': 'HBB77B0', 'major': '2', 'minor': '3' },
    'Z1020200': { 'osname': 'z/OS', 'hbb': 'HBB77A0', 'major': '2', 'minor': '2' },
  //    'Z01020100': search for 'ECVTPSEQ' in IBM document to find more versions to be supported
  };
  const DEF_FORMAT = '{major}.{minor}';

  common.printDebug(`formatZosVersion format=${format}, versionNumber=${versionNumber}`);

  let resolvedFormat = format, resolvedVersionNumber = versionNumber;
  if (typeof resolvedFormat !== 'string') {
    resolvedFormat = DEF_FORMAT;
  }
  if (resolvedVersionNumber === undefined) {
    // getZosVersion must return a number
    resolvedVersionNumber = zos.getZosVersion();
  }
  if (typeof resolvedVersionNumber === 'number') {
    resolvedVersionNumber = `Z${resolvedVersionNumber.toString(16)}`;
  }

  common.printDebug(`formatZosVersion parameter resolution format=${resolvedFormat}, versionNumber=${resolvedVersionNumber}`);

  let zosVer = ZOS_VERS[resolvedVersionNumber];
  if (!zosVer) {
    //TODO: should throw exception?
    zosVer = { 'osname': '?', 'hbb': '?', 'major': '?', 'minor': '?' };
    common.printError(`formatZosVersion unsupported z/OS version: specified=${versionNumber} resolved=${resolvedVersionNumber}`);
  }
  return resolvedFormat.replace(/\{\s*osname\s*\}/g, zosVer.osname)
    .replace(/\{\s*hbb\s*\}/g, zosVer.hbb)
    .replace(/\{\s*major\s*\}/g, zosVer.major)
    .replace(/\{\s*minor\s*\}/g, zosVer.minor);
}
