/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as xplatform from 'xplatform';

import * as common from '../../../libs/common';
import * as config from '../../../libs/config';
import * as component from '../../../libs/component';


export function execute(configPath: string, includeComponents?: boolean, onlyEnabled?: boolean) {
  let manifestReturn = xplatform.loadFileUTF8(`${std.getenv('ZWE_zowe_runtimeDirectory')}/manifest.json`,xplatform.AUTO_DETECT);
  if (manifestReturn) {
    const runtimeManifest = JSON.parse(manifestReturn);
    const zoweVersion = runtimeManifest ? runtimeManifest.version : undefined;
    common.printFormattedInfo("ZWELS", "zwe-internal-start-prepare", `Zowe version: v${zoweVersion}`);
    common.printFormattedInfo("ZWELS", "zwe-internal-start-prepare", `build and hash: ${runtimeManifest.build.branch}#${runtimeManifest.build.number} (${runtimeManifest.build.commitHash})`);
  } else {
    common.printError(`Could not read Zowe runtime manifest from runtime directory, cannot continue`);
    std.exit(1);
  }

  common.printMessage(`Validating Zowe core configuration for file(s)=${configPath}`);
  const ZOWE_CONFIG=config.getZoweConfig();
  //validation complete from here
  common.printMessage(`Zowe core configuration is valid`);
  
  if (includeComponents) {
    let components = onlyEnabled ? component.getEnabledComponents() : Object.keys(ZOWE_CONFIG.components);
    components.forEach((componentId: string)=> {
      const componentDir = component.findComponentDirectory(componentId);
      if (!componentDir) {
        common.printError(`Error: Component ${componentId} is not installed! Reinstall it, disable it, or remove it from the config.`);
      } else {
        const manifest = component.getManifest(componentDir);
        const configValid = component.validateConfigForComponent(componentId, manifest, componentDir, std.getenv('ZWE_CLI_PARAMETER_CONFIG'));
        if (configValid) {
          common.printMessage(`Component ${componentId} configuration is valid`);
        } else {
          common.printError(`Error: Component ${componentId} configuration is invalid`);
        }
      }
    });
  }
}
