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
import * as fs from '../../../../../../libs/fs';
import * as common from '../../../../../../libs/common';
import * as stringlib from '../../../../../../libs/string';
import * as config from '../../../../../../libs/config';
import * as component from '../../../../../../libs/component';
import { PathAPI as pathoid } from '../../../../../../libs/pathoid';

export function execute(componentName?: string, zisPluginDatasets?: string[], dryRun?: boolean) {
  common.requireZoweYaml();

  if (zisPluginDatasets) {
    let success = component.addPluginToZisSteplib(zisPluginDatasets, dryRun);
    if (!success) {
      common.printErrorAndExit(`ZIS plugin installation failed.`, undefined, 999);
    }
  } else {
    const ZOWE_CONFIG=config.getZoweConfig();
    // read extensionDirectory
    const extensionDir=ZOWE_CONFIG.zowe.extensionDirectory;
    if (!extensionDir) {
      common.printErrorAndExit("Error ZWEL0180E: Zowe extension directory (zowe.extensionDirectory) is not defined in Zowe YAML configuration file.", undefined, 180);
    }

    const targetDir = stringlib.removeTrailingSlash(extensionDir);
    const componentDir = pathoid.join(targetDir, componentName);

    const componentArg = std.getenv('ZWE_CLI_PARAMETER_COMPONENT_FILE');
    let dryRunDir;
    if (componentArg && fs.directoryExists(componentArg) && dryRun) {
      dryRunDir = componentArg;
    }
    
    let errors = component.addPluginsToZisAuthPluginLib((dryRun && dryRunDir) ? dryRunDir : componentDir, dryRun);
    if (errors.length > 0) {
      errors.forEach((error: {rc: number, plugin: string})=> {
        common.printError(`Error copying plugin ${error.plugin}, rc: ${error.rc}`);
      });
      common.printErrorAndExit(`ZIS plugin installation failed.`, undefined, 999);
    }
  }
}
