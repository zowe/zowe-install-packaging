/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as common from '../../../libs/common';
import * as config from '../../../libs/config';
import * as fs from '../../../libs/fs';

export function execute(quitOnError?: boolean) {
  const ZOWE_CONFIG=config.getZoweConfig();
  const mandatoryDirectories = {
    runtimeDirectory: 'the location of the Zowe installation',
    workspaceDirectory: 'a directory where this Zowe instance\'s persistent storage and temporary files will be stored',
    logDirectory: 'a directory where you want this Zowe instance to put its log files',
    extensionDirectory: 'a directory where extensions will be registered to this Zowe instance'
  };

    
  let keys = Object.keys(mandatoryDirectories);
  let runtimeDirectory = ZOWE_CONFIG.zowe.runtimeDirectory;
  let hasErrors = false;
  keys.forEach((directory)=> {
    let purpose = mandatoryDirectories[directory];
    let path = ZOWE_CONFIG.zowe[directory];
    if (!path) {
      common.printError(`Error: "zowe.${directory}" is not set. You must set it to ${purpose}.`);
      hasErrors = true;
    } else if (fs.directoryExists(path, false)) {
      common.printError(`Error: "zowe.${directory}" does not exist or cannot be accessed by the current user.`);
      hasErrors = true;
    } else if (directory != 'runtimeDirectory') {
      if (!runtimeDirectory.endsWith('/')) {
        runtimeDirectory+='/';
      }
      if (path.indexOf(runtimeDirectory) == '0') {
        common.printError(`Error: "zowe.${directory}" is set to be within the "zowe.runtimeDirectory", but this is not allowed.`);
        common.printError(`zowe.${directory}: ${path}`);
        common.printError(`zowe.runtimeDirectory: ${runtimeDirectory}`);
        hasErrors = true;
      }
    }
  });
  //TODO - check on keystore directory when pkcs12?
  if (!hasErrors) {
    common.printMessage(`Zowe directory validation passed.`);
  } else if (!quitOnError) {
    common.printError(`Zowe directory validation failed, review output for action items before running Zowe.`);
  } else {
    common.printErrorAndExit(`Zowe directory validation failed, review output for action items before running Zowe.`, null, 8);
  }
}
