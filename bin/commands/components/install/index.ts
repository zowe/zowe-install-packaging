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
import * as objUtils from '../../../utils/ObjUtils';

export function execute(componentFile: string, autoEncoding?:string, skipEnable?:boolean, handler?: string, registry?: string, dryRun?: boolean, upgrade?: boolean) {
  if (!fs.fileExists(componentFile) && !fs.directoryExists(componentFile)) {
    common.requireZoweYaml();
    if (componentFile && !upgrade) {
      const componentDir = componentlib.findComponentDirectory(componentFile);
      
      if (componentDir) {
        common.printMessage("Already installed");
        return;
      }
    }
    //We only call the registry handler if given an argument thats not a path. If the handler returns null, we must fail because there's nothing left to do.
    componentFile = handlerInstall(componentFile, handler, registry, dryRun, upgrade);

    if (componentFile==='null' && !dryRun) {
      common.printErrorAndExit("Error ZWEL????E: Handler install failure, cannot continue", undefined, 255);
    }
  }

  //if upgrade with 'all', or if a component had dependencies, there could be a list of things to act upon here
  // TODO this does not allow multi install from package due to the initial existence check, but maybe we could enable that later.
  const components = componentFile.split(',');

  components.forEach((componentFile: string) => {
    if (componentFile==='null') {
      //TODO wish more could be said here
      common.printError("Error ZWEL????E: Could not find one of the components' directories");
    } else {
      common.printMessage(`Installing file or folder=${componentFile}`);
      if (!dryRun) {
        extract.execute(componentFile, autoEncoding, upgrade);
        
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
    }
  });
}

function handlerInstall(component: string, handler?: string, registry?: string, dryRun?: boolean, upgrade?: boolean): string {
  const ZOWE_CONFIG=config.getZoweConfig();
  std.setenv("ZWE_zowe_extensionDirectory", ZOWE_CONFIG.zowe.extensionDirectory);

  if (component === 'all' && !upgrade) {
    common.printErrorAndExit("Error ZWEL????E: Cannot install with component=all. This option only exists for upgrade.", undefined, 255);
  } else if (component === 'all') {
    const allExtensions = componentlib.findAllInstalledComponents2().filter(component=> componentlib.findComponentDirectory(component).startsWith(ZOWE_CONFIG.zowe.extensionDirectory+'/')).join(',');
    if (allExtensions) {
      //all extensions doesnt mean every one exists from this handler. handler must check them.
      component = allExtensions;
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

  //TODO some scripts use COMPONENT_NAME, others COMPONENT_FILE, COMPONENT_ID...simplify the API. I'm assigning COMPONENT_NAME for simplicity.
  std.setenv("ZWE_CLI_PARAMETER_COMPONENT_NAME", component);
  
  const handlerPath = ZOWE_CONFIG.zowe.extensionRegistry.handlers[handler].path;

  //one of the extension registry handler API commands
  std.setenv('ZWE_CLI_REGISTRY_COMMAND', upgrade ? 'upgrade' : 'install');

  std.setenv('ZWE_CLI_REGISTRY_DRY_RUN', dryRun ? 'true' : 'false');

  const flattener = new objUtils.Flattener();
  flattener.setPrefix('ZWE_');
  flattener.setSeparator('_');
  flattener.setKeepArrays(true);
  const flat = flattener.flatten(ZOWE_CONFIG.zowe.extensionRegistry.handlers[handler]);
  //give handler its zowe.yaml config section
  flat.forEach((env:string) => {
    const key = env.substr(0, env.indexOf('='));
    const val = env.substr(env.indexOf('='));
    std.setenv(key,val);
  });

  common.printMessage(`Calling handler '${handler}' to install ${component}`);

  const result = shell.execOutSync('sh', '-c', `_CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${std.getenv('ZWE_zowe_runtimeDirectory')}/bin/utils/configmgr -script "${handlerPath}"`);
  common.printMessage(`Handler install exited with rc=${result.rc}`);

  if (result.rc) {
    common.printError(`Handler output follows`);
    common.printMessage(result.out);
    return 'null';
  }
  let output = result.out.split('\n').filter(line => line.startsWith('ZWE_CLI_PARAMETER_COMPONENT_FILE='));
  if (output[0]) {
    return output[0].substring('ZWE_CLI_PARAMETER_COMPONENT_FILE='.length);
  }
  return 'null';
}
