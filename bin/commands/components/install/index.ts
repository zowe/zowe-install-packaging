/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'std';
import * as extract from './extract/index';
import * as installHook from './process-hook/index';
import * as componentEnable from '../enable/index';
import * as common from '../../../libs/common';
import * as fs from '../../../libs/fs';
import * as config from '../../../libs/config';
import * as componentlib from '../../../libs/component';
import * as shell from '../../../libs/shell';

export function execute(componentFile: string, autoEncoding?:string, skipEnable?:boolean, handler?: string, registry?: string) {
  if (!fs.fileExists(componentFile) && !fs.directoryExists(componentFile)) {
    componentFile = handlerInstall(componentFile, handler, registry);
    if (!componentFile) {
      common.printErrorAndExit("Error ZWEL????E: Handler install failure, cannot continue", undefined, 255);
    }
  }
  extract.execute(componentFile, autoEncoding);
  // ZWE_COMPONENTS_INSTALL_EXTRACT_COMPONENT_NAME should be set after extract step
  const componentName = std.getenv('ZWE_COMPONENTS_INSTALL_EXTRACT_COMPONENT_NAME');
  if (componentName) {
    installHook.execute(componentName);
  } else {
    common.printErrorAndExit("Error ZWEL0156E: Component name is not initialized after extract step.", undefined, 156);
  }
  if (!skipEnable) {
    componentEnable.execute(componentName);
  }
}

function handlerInstall(component: string, handler?: string, registry?: string): string {
  common.requireZoweYaml();
  const ZOWE_CONFIG=config.getZoweConfig();


  if (component) {
    const componentDir = componentlib.findComponentDirectory(component);
    
    if (componentDir) {
      common.printMessage("Already installed");
      return "";
    }
  }

  
  if (!handler) {
    handler=ZOWE_CONFIG.zowe.extensionRegistry?.defaultHandler;
    if (!handler) {
      common.printErrorAndExit("Error ZWEL????E: Handler (-handler,-h or zowe.extensionRegistry.defaultHandler) required but not specified", undefined, 255);
    }
  }
  std.setenv('ZWE_CLI_PARAMETER_HANDLER',handler);

  if (!registry) {
    registry=ZOWE_CONFIG.zowe.extensionRegistry.handlers[handler].registry;
  }
  std.setenv('ZWE_CLI_PARAMETER_REGISTRY',registry);
  
  const handlerPath = ZOWE_CONFIG.zowe.extensionRegistry.handlers[handler].path;

  //one of the extension registry handler API commands
  std.setenv('ZWE_CLI_REGISTRY_COMMAND','install');

  const result = shell.execSync('sh', '-c', `_CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${std.getenv('ZWE_zowe_runtimeDirectory')}/bin/utils/configmgr -script "${handlerPath}"`);
  common.printMessage(`Handler install exited with rc=${result.rc}`);

  //one of the extension registry handler API commands
  std.setenv('ZWE_CLI_REGISTRY_COMMAND','getpath');
  
  const pathResult = shell.execOutSync('sh', '-c', `_CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${std.getenv('ZWE_zowe_runtimeDirectory')}/bin/utils/configmgr -script "${handlerPath}"`);
  common.printMessage(`Handler getpath exited with rc=${result.rc}`);
  return pathResult.out;
}
