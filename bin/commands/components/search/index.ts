/*
// This program and the accompanying materials are made available
// under the terms of the Eclipse Public License v2.0 which
// accompanies this distribution, and is available at
// https://www.eclipse.org/legal/epl-v20.html
//
// SPDX-License-Identifier: EPL-2.0
//
// Copyright Contributors to the Zowe Project.
*/

import * as std from 'std';
import * as common from '../../../libs/common';
import * as config from '../../../libs/config';
import * as component from '../../../libs/component';
import * as shell from '../../../libs/shell';

export function execute(componentName?: string, componentId?: string, handler?: string, registry?: string) {
  
  common.requireZoweYaml();
  const ZOWE_CONFIG=config.getZoweConfig();

  if (componentName) {
    const componentDir = component.findComponentDirectory(componentName);
    
    if (componentDir) {
      const manifest = component.getManifest(componentDir);
      const enabled=ZOWE_CONFIG.components[componentName] && ZOWE_CONFIG.components[componentName].enabled == 'true';
      common.printMessage(`Component ${manifest.name} ${manifest.id ? '('+manifest.id+')' : ''} status: ${enabled ? 'ENABLED' : 'DISABLED'} ${manifest.version ? 'version: '+manifest.version : ''} `);
    } else {
      common.printMessage(`Component ${componentName} status: UNINSTALLED`);
    }
  } else if (!componentId) {
    common.printErrorAndExit("Error ZWEL????E: Component name (-name|-n) or id (-id,-d) required but not specified", undefined, 255);
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
  std.setenv('ZWE_CLI_REGISTRY_COMMAND','search');

  const result = shell.execSync('sh', '-c', `_CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${std.getenv('ZWE_zowe_runtimeDirectory')}/bin/utils/configmgr -script "${handlerPath}"`);
  common.printMessage(`Handler exited with rc=${result.rc}`);
}
