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
import * as common from '../../../libs/common';
import * as fs from '../../../libs/fs';
import * as config from '../../../libs/config';
import * as componentlib from '../../../libs/component';
import * as shell from '../../../libs/shell';
import * as componentDisable from '../disable/index';

export function execute(componentFile: string, handler?: string, registry?: string) {

  common.requireZoweYaml();
  const ZOWE_CONFIG=config.getZoweConfig();
  std.setenv("ZWE_zowe_extensionDirectory", ZOWE_CONFIG.zowe.extensionDirectory);

  
  const componentDir = componentlib.findComponentDirectory(componentFile);
  if (!componentDir) {
    common.printErrorAndExit(`Warning ZWEL????W: Component ${componentFile} is not installed`, undefined, 4);
  }

  const removeRc = os.remove(componentDir);
  if (removeRc < 0) {
    common.printErrorAndExit(`Error ZWEL????W: Component directory ${componentDir} could not be removed, rc=${removeRc}`, undefined, removeRc);
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
  std.setenv('ZWE_CLI_REGISTRY_COMMAND','uninstall');

  const result = shell.execSync('sh', '-c', `_CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${std.getenv('ZWE_zowe_runtimeDirectory')}/bin/utils/configmgr -script "${handlerPath}"`);
  common.printMessage(`Handler uninstall exited with rc=${result.rc}`);


  componentDisable.execute(componentFile);
}
