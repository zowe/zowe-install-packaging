/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
  
  SPDX-License-Identifier: EPL-2.0
  
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as common from '../../../../libs/common';
import * as shell from '../../../../libs/shell';
import * as fs from '../../../../libs/fs';

export function execute() {
  common.printLevel0Message( "Prepare Zowe containerization runtime environment");


  // Constants
  const containerRuntimeDirectory = std.getenv('ZWE_PRIVATE_CONTAINER_RUNTIME_DIRECTORY');
  const containerComponentRuntimeDirectory = std.getenv('ZWE_PRIVATE_CONTAINER_COMPONENT_RUNTIME_DIRECTORY');
  const containerHomeDirectory = std.getenv('ZWE_PRIVATE_CONTAINER_HOME_DIRECTORY');
  const containerWorkspaceDirectory = std.getenv('ZWE_PRIVATE_CONTAINER_WORKSPACE_DIRECTORY');
  const pluginsDir = `${containerWorkspaceDirectory}/app-server/plugins`;
  const staticDefConfigDir = `${containerWorkspaceDirectory}/api-mediation/api-defs`;


  common.printLevel1Message("Before preparation");
  common.printMessage(`  - whoami? ${common.getUserId()}`);
  common.printMessage(`  - ${containerComponentRuntimeDirectory}`);
  shell.execSync('ls', '-la', containerComponentRuntimeDirectory);
  common.printMessage("  - /home");
  shell.execSync('ls', '-la', "/home");
  common.printMessage("  - /home/zowe");
  shell.execSync('ls', '-la', "/home/zowe");


  common.printLevel1Message("Prepare runtime directory");
  fs.mkdirp(`${containerRuntimeDirectory}/components`);
  fs.cpr(`${containerComponentRuntimeDirectory}/.`, containerRuntimeDirectory);


  common.printLevel1Message("Prepare log and workspace directories");
  fs.mkdirp(`${containerWorkspaceDirectory}/tmp`);
  fs.createFile(`${containerWorkspaceDirectory}/.init-for-container`, 0o770);


  common.printLevel1Message("After preparation");
  common.printMessage(`  - ${containerComponentRuntimeDirectory}`);
  shell.execSync('ls', '-la', containerComponentRuntimeDirectory);
  common.printMessage(`  - ${containerHomeDirectory}`);
  shell.execSync('ls', '-la', containerHomeDirectory);

  if (fs.directoryExists(containerRuntimeDirectory)) {
    common.printMessage(`  - ${containerRuntimeDirectory}`);
    shell.execSync('ls', '-la', containerRuntimeDirectory);
  }
  if (fs.directoryExists(`${containerRuntimeDirectory}/components`)) {
    common.printMessage(`  - ${containerRuntimeDirectory}/components`);
    shell.execSync('ls', '-la', `${containerRuntimeDirectory}/components`);
  }
  if (fs.directoryExists(containerWorkspaceDirectory)) {
    common.printMessage(`  - ${containerWorkspaceDirectory}`);
    shell.execSync('ls', '-la', containerWorkspaceDirectory);
  }
  if (fs.directoryExists(pluginsDir)) {
    common.printMessage(`  - ${pluginsDir}`);
    shell.execSync('ls', '-la', pluginsDir);
  }
  if (fs.directoryExists(staticDefConfigDir)) {
    common.printMessage(`  - ${staticDefConfigDir}`);
    shell.execSync('ls', '-la', staticDefConfigDir);
  }

  // exit message
  common.printLevel1Message("Zowe containerization runtime environment is prepared successfully.");
}
