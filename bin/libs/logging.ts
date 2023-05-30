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

import * as common from './common';
import * as fs from './fs';
import * as stringlib from './string';


std.unsetenv('ZWE_PRIVATE_LOG_FILE');


export function prepareLogFile(logDir: string, logFilePrefix: string): void {
  logDir=stringlib.removeTrailingSlash(fs.convertToAbsolutePath(logDir) as string);

  const logFile=`${logDir}/${logFilePrefix}-${common.date('+%Y%m%dT%H%M%S')}.log`;
  if (!fs.fileExists(logFile)) {
    fs.mkdirp(logDir, 0o770);
    if (!fs.isDirectoryWritable(logDir)) {
      common.printErrorAndExit("Error ZWEL0110E: Doesn't have write permission on ${1} directory.", undefined, 110);
    }
    let success = fs.createFile(logFile, 0o666);
    common.printDebug(`Log file created: ${logFile}`, ["console"]);
  }
}
