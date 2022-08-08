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
import * as componentlib from '../../../libs/component';
import * as componentDisable from '../disable/index';
import { HandlerCaller, getHandler, getRegistry } from '../handlerutils';

export function execute(componentName: string, handler?: string, registry?: string, dryRun?: boolean): number {
  let rc = 0;
  common.requireZoweYaml();

  //Attempt to involve the registry handler if exists. If it doesnt exist that's ok, we need to do zowe steps of uninstall anyway.
  let handlerComponents = handlerUninstall(componentName, handler, registry, dryRun);
  let uninstallComponentsList = handlerComponents !== 'null' ? handlerComponents.split(',') : [ componentName ];

  common.printMessage(`Identified ${uninstallComponentsList.length} components for removal`);
  
  uninstallComponentsList.forEach((componentName: string) => {
    common.printMessage(`Checking component '${componentName}'`);
    
    const componentDir = componentlib.findComponentDirectory(componentName);
    if (!componentDir) {
      common.printError(`Warning ZWEL????W: Component ${componentName} marked for removal but is not installed`);
      rc = 4;
    } else {
      common.printMessage(`Disabling component ${componentName} in configuration`);
      if (!dryRun) {
        //We dont remove the entire config because if they reinstall, they may want to retain the settings.
        componentDisable.execute(componentName);
      }

      common.printMessage(`Removing component directory '${componentDir}'`);
      if (!dryRun) {
        const removeRc = fs.rmrf(componentDir);
        if (removeRc != 0) {
          common.printError(`Error ZWEL????W: Component directory ${componentDir} could not be removed, rc=${removeRc}`);
          rc = removeRc;
        }
      }
    }
  });
  return rc;
}


function handlerUninstall(componentName: string, handler?: string, registry?: string, dryRun?: boolean): string {
  handler = getHandler(handler);
  if (!handler) {
    common.printMessage("Zowe registry handler not found. If component was installed without a registry, this is OK. Otherwise, you may need to clean up the handler cache manually.");
    return 'null';
  }
  registry = getRegistry(handler, registry);  
  const handlerCaller = new HandlerCaller(handler, registry);

  return handlerCaller.uninstall(componentName, dryRun);
}
