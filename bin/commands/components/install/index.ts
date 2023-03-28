/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as extract from './extract/index';
import * as installHook from './process-hook/index';
import * as componentEnable from '../enable/index';
import * as common from '../../../libs/common';
import * as fs from '../../../libs/fs';
import * as config from '../../../libs/config';
import * as componentlib from '../../../libs/component';
import { HandlerCaller, getHandler, getRegistry } from '../handlerutils';

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
      common.printErrorAndExit("Error ZWEL0304E: Handler install failure, cannot continue.", undefined, 304);
    }
  }

  //if upgrade with 'all', or if a component had dependencies, there could be a list of things to act upon here
  // TODO this does not allow multi install from package due to the initial existence check, but maybe we could enable that later.
  const components = componentFile.split(',');

  components.forEach((componentFile: string) => {
    if (componentFile==='null') {
      //TODO wish more could be said here
      common.printError("Error ZWEL0305E: Could not find one of the components' directories.");
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

  if (component === 'all' && !upgrade) {
    common.printErrorAndExit("Error ZWEL0314E: Cannot install with component=all. This option only exists for upgrade.", undefined, 314);
  } else if (component === 'all') {
    const allExtensions = componentlib.findAllInstalledComponents2().filter(component=> componentlib.findComponentDirectory(component).startsWith(ZOWE_CONFIG.zowe.extensionDirectory+'/')).join(',');
    if (allExtensions) {
      //all extensions doesnt mean every one exists from this handler. handler must check them.
      component = allExtensions;
    }
  }

  handler = getHandler(handler);
  if (!handler) {
    common.printErrorAndExit("Error ZWEL0315E: Handler (-handler or zowe.extensionRegistry.defaultHandler) required but not specified.", undefined, 255);
  }
  registry = getRegistry(handler, registry);  
  const handlerCaller = new HandlerCaller(handler, registry);

  return upgrade ? handlerCaller.upgrade(component, dryRun) : handlerCaller.install(component, dryRun);
}
