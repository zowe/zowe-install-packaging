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
import * as xplatform from 'xplatform';

import * as fs from '../../../../libs/fs';
import * as common from '../../../../libs/common';
import * as stringlib from '../../../../libs/string';
import * as shell from '../../../../libs/shell';
import * as sys from '../../../../libs/sys';
import * as config from '../../../../libs/config';
import * as component from '../../../../libs/component';
import * as varlib from '../../../../libs/var';
import * as java from '../../../../libs/java';
import * as node from '../../../../libs/node';
import * as zosmf from '../../../../libs/zosmf';
import * as pathoid from '../../../../libs/pathoid';

export function execute(componentName: string) {
  common.requireZoweYaml();
  const ZOWE_CONFIG=config.getZoweConfig();
  // read extensionDirectory
  extensionDir=ZOWE_CONFIG.zowe.extensionDirectory;
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
    // run commands
    const result = shell.execOutSync('sh', '-c', `. ${runtimeDirectory}/bin/libs/index.sh && . ${scriptPath}`);
  } else {
    common.printDebug(`Module ${componentName} does not have commands.install defined.`);
  }

  if (os.platform == 'zos') {
    component.processZssPluginInstall(componentDir);
  }
}
