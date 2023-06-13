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
import * as stringlib from '../../../../libs/string';
import * as shell from '../../../../libs/shell';
import * as config from '../../../../libs/config';
import * as component from '../../../../libs/component';
import * as varlib from '../../../../libs/var';
import { PathAPI as pathoid } from '../../../../libs/pathoid';

export function execute(componentName: string) {
  common.requireZoweYaml();
  const ZOWE_CONFIG=config.getZoweConfig();
  // read extensionDirectory
  const extensionDir=ZOWE_CONFIG.zowe.extensionDirectory;
  if (!extensionDir) {
    common.printErrorAndExit("Error ZWEL0180E: Zowe extension directory (zowe.extensionDirectory) is not defined in Zowe YAML configuration file.", undefined, 180);
  }

  const targetDir = stringlib.removeTrailingSlash(extensionDir);
  const componentDir = pathoid.join(targetDir, componentName);
  const manifest = component.getManifest(componentDir);
  const installScript = manifest.commands ? manifest.commands.install : undefined;
  if (installScript) {
    common.printMessage(`Process ${installScript} defined in manifest commands.install:`);
    const scriptPath = pathoid.join(targetDir, componentName, installScript);
    const componentRoot = pathoid.join(targetDir, componentName);
    // run commands
    const result = shell.execOutSync('sh', '-c', `. ${ZOWE_CONFIG.zowe.runtimeDirectory}/bin/libs/configmgr-index.sh && cd ${componentRoot} && . ${scriptPath} ; export rc=$? ; export -p`);
    if (result.rc==0) {
      varlib.getEnvironmentExports(result.out, true);
      const outLines = result.out.split('\n');
      common.printFormattedInfo("ZWELS", "zwe-components-install-process-hook", `- commands.install output from ${componentName} is:`);
      common.printMessage(outLines.filter(line => !line.startsWith('export ')).join('\n'));
      common.printFormattedDebug("ZWELS", "zwe-components-install-process-hook", outLines.filter(line => line.startsWith('export ')).join('\n'));
    } else {
      common.printError(`install script ended with error, rc=${result.rc}`);
      if (result.out) {
        const outLines = result.out.split('\n');
        common.printFormattedInfo("ZWELS", "zwe-components-install-process-hook", `- commands.install output from ${componentName} is:`);
        common.printMessage(outLines.filter(line => !line.startsWith('export ')).join('\n'));
      }
      std.exit(result.rc);
    }

  } else {
    common.printDebug(`Module ${componentName} does not have commands.install defined.`);
  }

  component.processZssPluginInstall(componentDir);
  component.processZisPluginInstall(componentDir);
}
