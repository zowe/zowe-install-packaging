/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as os from 'cm_os';
import * as zos from 'zos';

import * as common from './common';
import * as shell from './shell';

export function validateZosmfHostAndPort(zosmfHost: string, zosmfPort: number): boolean {
  if (!zosmfHost) {
    common.printError('z/OSMF host is not set.');
    return false;
  }
  if (!zosmfPort) {
    common.printError('z/OSMF port is not set.');
    return false;
  }
  let zosmfCheckPassed=true;

  if (!std.getenv('NODE_HOME')) {
    common.printError(`Warning: Could not validate if z/OS MF is available on 'https://${zosmfHost}:${zosmfPort}/zosmf/info'. NODE_HOME is not defined.`);
    zosmfCheckPassed=false;
  } else {
    let execReturn = shell.execOutSync(`${std.getenv('NODE_HOME')}/bin/node`, `${std.getenv('ZWE_zowe_runtimeDirectory')}/bin/utils/curl.js`, `"https://${zosmfHost}:${zosmfPort}/zosmf/info"`, `-k`, `-H`, `"X-CSRF-ZOSMF-HEADER: true"`, `--response-type`, `status`);
    if (execReturn.rc || !execReturn.out) {
      common.printError(`Warning: Could not validate if z/OS MF is available on 'https://${zosmfHost}:${zosmfPort}/zosmf/info'. No response code from z/OSMF server.`);
      zosmfCheckPassed=false
    } else if (execReturn.out != '200') {
      common.printError(`Could not contact z/OS MF on 'https://${zosmfHost}:${zosmfPort}/zosmf/info' - ${execReturn.out}`);
      zosmfCheckPassed=false
      return false;
    }
  }

  if (zosmfCheckPassed) {
    common.printMessage(`Successfully checked z/OS MF is available on 'https://${zosmfHost}:${zosmfPort}/zosmf/info'`)
  }
  return zosmfCheckPassed;
}

//TODO isnt this completely backwards?
export function validateZosmfAsAuthProvider(zosmfHost: string, zosmfPort: number, authProvider: string): boolean {
  if (zosmfHost && zosmfPort) {
    if (authProvider == 'zosmf') {
      common.printError("z/OSMF is not configured. Using z/OSMF as authentication provider is not supported.");
      return true;
    }
  }
  return false;
}
