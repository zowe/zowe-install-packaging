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

export function execute(componentFile: string, handler?: string, registry?: string, dryRun?: boolean) {

  common.requireZoweYaml();
  const ZOWE_CONFIG=config.getZoweConfig();
  std.setenv("ZWE_zowe_extensionDirectory", ZOWE_CONFIG.zowe.extensionDirectory);

  
  const componentDir = componentlib.findComponentDirectory(componentFile);
  if (!componentDir) {
    common.printErrorAndExit(`Warning ZWEL????W: Component ${componentFile} is not installed`, undefined, 4);
  }

  //We dont remove the entire config because if they reinstall, they may want to retain the settings.
  componentDisable.execute(componentFile);
  
  const removeRc = fs.rmrf(componentDir);
  if (removeRc != 0) {
    common.printErrorAndExit(`Error ZWEL????W: Component directory ${componentDir} could not be removed, rc=${removeRc}`, undefined, removeRc);
  }

  
  if (!handler) {
    handler=ZOWE_CONFIG.zowe.extensionRegistry?.defaultHandler;
  }


  if (!handler) {
    common.printMessage("Zowe registry handler not found. If component was installed without a registry, this is OK. Otherwise, you may need to clean up the handler cache manually.");
  } else {
    std.setenv('ZWE_CLI_PARAMETER_HANDLER',handler);
    
    if (!registry) {
      registry=ZOWE_CONFIG.zowe.extensionRegistry.handlers[handler].registry;
    }
    std.setenv('ZWE_CLI_PARAMETER_REGISTRY',registry);
    
    const handlerPath = ZOWE_CONFIG.zowe.extensionRegistry.handlers[handler].path;

    //TODO some scripts use COMPONENT_NAME, others COMPONENT_FILE, COMPONENT_ID...simplify the API. I'm assigning COMPONENT_NAME for simplicity.
    std.setenv("ZWE_CLI_PARAMETER_COMPONENT_NAME", componentFile);
    
    //one of the extension registry handler API commands
    std.setenv('ZWE_CLI_REGISTRY_COMMAND','uninstall');

    std.setenv('ZWE_CLI_REGISTRY_DRY_RUN', dryRun ? 'true' : 'false');
    
    const result = shell.execSync('sh', '-c', `_CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${std.getenv('ZWE_zowe_runtimeDirectory')}/bin/utils/configmgr -script "${handlerPath}"`);
    common.printMessage(`Handler uninstall exited with rc=${result.rc}`);
  }

}
