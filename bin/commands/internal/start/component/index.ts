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
import * as xplatform from 'xplatform';
import * as common from '../../../../libs/common';
import * as config from '../../../../libs/config';
import * as shell from '../../../../libs/shell';
import * as varlib from '../../../../libs/var';
import * as stringlib from '../../../../libs/string';
import * as java from '../../../../libs/java';
import * as fs from '../../../../libs/fs';
import * as component from '../../../../libs/component';
import { PathAPI as pathoid } from '../../../../libs/pathoid';

export function execute(componentId: string, runInBackground: boolean=false) {
  std.setenv('ZWE_CLI_PARAMETER_COMPONENT', componentId);
  
  const coreComponents = std.getenv('ZWE_PRIVATE_CORE_COMPONENTS_REQUIRE_JAVA');
  if (coreComponents && coreComponents.includes(componentId)) {
    java.requireJava();
  }

  common.requireZoweYaml();

  const ZOWE_CONFIG=config.getZoweConfig();

  const runtimeDirectory = ZOWE_CONFIG.zowe.runtimeDirectory;

  // overwrite ZWE_PRIVATE_LOG_LEVEL_ZWELS with zowe.launchScript.logLevel config in YAML
  if (ZOWE_CONFIG.zowe.launchScript) {
    std.setenv('ZWE_PRIVATE_LOG_LEVEL_ZWELS', ZOWE_CONFIG.zowe.launchScript.logLevel.toUpperCase());
  };

  // check and sanitize ZWE_CLI_PARAMETER_HA_INSTANCE
  config.sanitizeHaInstanceId();

  const WORKSPACE_DIRECTORY = ZOWE_CONFIG.zowe.workspaceDirectory;
  if (!WORKSPACE_DIRECTORY) {
    common.printErrorAndExit("Error ZWEL0157E: Zowe workspace directory (zowe.workspaceDirectory) is not defined in Zowe YAML configuration file.", undefined, 157);
  }

  // load environment
  config.loadEnvironmentVariables(componentId);

  // find component root directory and execute start script
  const COMPONENT_DIR = component.findComponentDirectory(componentId);
  common.printFormattedTrace("ZWELS", "zwe-internal-start-component", `- found ${componentId} in directory ${COMPONENT_DIR}`);
  if (COMPONENT_DIR) {
    let dir = COMPONENT_DIR;
    const manifest = component.getManifest(COMPONENT_DIR);
    
    const privateWorkspaceDir=std.getenv('ZWE_PRIVATE_WORKSPACE_ENV_DIR');
    //TODO CLI_PARAMETER vars come from cli --parameters, and so should be mapped to execute() parameters. This probably doesnt work.
    const haInstance = std.getenv('ZWE_CLI_PARAMETER_HA_INSTANCE');
    
    // source environment snapshot created by configure step
    const componentName = pathoid.basename(COMPONENT_DIR);

    if (fs.fileExists(`${privateWorkspaceDir}/${componentName}/.${haInstance}.env`)) {
      common.printFormattedDebug("ZWELS", "zwe-internal-start-component", `restoring environment snapshot ${privateWorkspaceDir}/${componentName}/.${haInstance}.env ...`);
      varlib.sourceEnv(`${privateWorkspaceDir}/${componentName}/.${haInstance}.env`);
      std.setenv('ZWE_CLI_PARAMETER_COMPONENT', componentId);
    }


    let startScript = manifest.commands ? manifest.commands.start : undefined;
    common.printFormattedTrace("ZWELS", "zwe-internal-start-component", `- command.start of ${componentId} is ${startScript}`);

    if (startScript) {
      const fullPath = `${COMPONENT_DIR}/${startScript}`;
      if (fs.fileExists(fullPath)) {
        common.printFormattedInfo("ZWELS", "zwe-internal-start-component", `starting component ${componentId} ...`);
        common.printFormattedTrace("ZWELS", "zwe-internal-start-component", `>>> environment for ${componentId}\n`);
        let environment = std.getenviron();
        let keys = Object.keys(environment);
        keys.forEach((key: string) => {
          common.printTrace(`${key}=${environment[key]}`);
        });
        common.printTrace('<<<');
        // FIXME: we have assumption here startScript is pointing to a shell script
        // if [[ "${start_script}" == *.sh ]]; then
        if (runInBackground === true) {
          shell.exec('sh', '-c', `. ${runtimeDirectory}/bin/libs/configmgr-index.sh && cd ${COMPONENT_DIR} && . ${fullPath}`);
        } else {
          // wait for all background subprocesses created by bin/start.sh exit
          // re-source libs is necessary to reclaim shell functions since this will be executed in a new shell
          const startScriptContents = `cd ${COMPONENT_DIR} ; . "${ZOWE_CONFIG.zowe.runtimeDirectory}/bin/libs/configmgr-index.sh" ; ${xplatform.loadFileUTF8(fullPath, xplatform.AUTO_DETECT)} ; wait;`;
          const pipeArray = os.pipe();
          if (!pipeArray) {
            common.printFormattedError("ZWELS", "zwe-internal-start-component", `Error ZWEL0064E: failed to run command os.pipe - Cannot start component ${componentId}`);
            return;
          }
          //TODO this will not work with unicode codepoints longer than a byte
          const buf = new ArrayBuffer(startScriptContents.length);
          const view = new Uint8Array(buf);
          const ebcdicString = stringlib.asciiToEbcdic(startScriptContents);
          for (let i = 0; i < startScriptContents.length; i++) {
            view[i] = ebcdicString.charCodeAt(i);
          }

          os.write(pipeArray[1], buf, 0, startScriptContents.length);
          os.close(pipeArray[1]);
          os.exec(['/bin/sh'],
                  {block: true, usePath: true, stdin: pipeArray[0]});
          os.close(pipeArray[0]);
          
        }
      } else {
        common.printFormattedError("ZWELS", "zwe-internal-start-component", `Error ZWEL0172E: Component ${componentId} has commands.start defined but the file is missing.`);
      }
    } else {
      common.printFormattedTrace("ZWELS", "zwe-internal-start-component", `Component ${componentId} doesn't have start command.`);
    }
  } else {
    common.printFormattedError("ZWELS", "zwe-internal-start-component", `Failed to locate component directory for ${componentId}.`);
  }
}
