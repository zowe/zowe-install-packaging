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
import * as fs from '../../../../libs/fs';
import * as common from '../../../../libs/common';
import * as stringlib from '../../../../libs/string';
import * as shell from '../../../../libs/shell';
import * as sys from '../../../../libs/sys';
import * as config from '../../../../libs/config';
import * as component from '../../../../libs/component';

//# This command prepares everything needed to start Zowe.

const runtimeDirectory=std.getenv('ZWE_zowe_runtimeDirectory');
const extensionDirectory=std.getenv('ZWE_zowe_extensionDirectory');
const workspaceDirectory=std.getenv('ZWE_zowe_workspaceDirectory');


// Extra preparations for running in container
// - link component runtime under zowe <runtime>/components
// - `commands.configureInstance` is deprecated in v2
function prepareRunningInContainer() {
  // gracefully shutdown all processes
  common.printFormattedDebug("ZWELS", "zwe-internal-start-prepare,prepare_running_in_container", "Register SIGTERM handler for graceful shutdown.");
  os.signal(os.SIGTERM, sys.gracefullyShutdown());

  // read ZWE_PRIVATE_CONTAINER_COMPONENT_ID from component manifest
  // /component is hardcoded path we asked for in conformance
  const manifest = component.getManifest('/component');
  if (!manifest) {
    return 1; //TODO error code
  }
  let componentId = std.getenv('ZWE_PRIVATE_CONTAINER_COMPONENT_ID');
  if (componentId) {
    componentId = manifest.name;
    std.setenv('ZWE_PRIVATE_CONTAINER_COMPONENT_ID', componentId);
  }

  common.printFormattedTrace("ZWELS", "zwe-internal-start-prepare,prepare_running_in_container:", `Prepare <runtime>/components/${componentId} directory.`);
  if (fs.directoryExists(`${runtimeDirectory}/components/${componentId}`)) {
    shell.execSync('rm', `-rf "${runtimeDirectory}/components/${componentId}"`);
  }
  os.symlink(`${runtimeDirectory}/components/${componentId}`, '/component');
}

// Prepare log directory
function prepareLogDirectory() {
  const logDir = std.getenv('ZWE_zowe_logDirectory');
  if (logDir) {
    std.mkdir(logDir, 0o750);
    if (!fs.isDirectoryWritable(logDir)) {
      common.printFormattedError("ZWELS", "zwe-internal-start-prepare,prepare_log_directory", `ZWEL0141E: User $(get_user_id) does not have write permission on ${logDir}.`);
      std.exit(141);
    }
  }
}

// Prepare workspace directory
function prepareWorkspaceDirectory() {
  const zwePrivateWorkspaceEnvDir=`${workspaceDirectory}/.env`;
  std.setenv('ZWE_PRIVATE_WORKSPACE_ENV_DIR', zwePrivateWorkspaceEnvDir);
  const zweStaticDefinitionsDir=`${workspaceDirectory}/api-mediation/api-defs`;
  std.setenv('ZWE_STATIC_DEFINITIONS_DIR', zweStaticDefinitionsDir);
  const zweGatewaySharedLibs=`${workspaceDirectory}/gateway/sharedLibs/`;
  std.setenv('ZWE_GATEWAY_SHARED_LIBS', zweGatewaySharedLibs);
  const zweDiscoverySharedLibs=`${workspaceDirectory}/discovery/sharedLibs/`;
  std.setenv('ZWE_DISCOVERY_SHARED_LIBS', zweDiscoverySharedLibs);

  let rc = fs.mkdirp(workspaceDirectory, 0o770);
  if (rc != 0) {
    common.printFormattedError("ZWELS", "zwe-internal-start-prepare,prepare_workspace_directory", `WARNING: Failed to set permission of some existing files or directories in ${workspaceDirectory}:`);
    common.printFormattedError("ZWELS", "zwe-internal-start-prepare,prepare_workspace_directory" , ''+rc);
  }

  // Create apiml dirs
  fs.mkdirp(zweStaticDefinitionsDir, 0o770);
  fs.mkdirp(zweGatewaySharedLibs, 0o770);
  fs.mkdirp(zweDiscoverySharedLibs, 0o770);

  shell.execSync('cp', `"${runtimeDirectory}/manifest.json" "${workspaceDirectory}"`);

  fs.mkdirp(zwePrivateWorkspaceEnvDir, 0o700);

  const zweCliParameterHaInstance = std.getenv('ZWE_CLI_PARAMETER_HA_INSTANCE');
  common.printFormattedDebug("ZWELS", "zwe-internal-start-prepare,prepare_workspace_directory", `initialize .instance-${zweCliParameterHaInstance}.env(s)`);
  config.generateInstanceEnvFromYamlConfig(zweCliParameterHaInstance);
}

// Validation
common.requireZoweYaml();

// Read job name and validate
//const zoweConfig = config.getZoweConfig();
