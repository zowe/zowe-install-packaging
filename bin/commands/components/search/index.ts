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

import * as std from 'cm_std';
import * as common from '../../../libs/common';
import * as config from '../../../libs/config';
import * as component from '../../../libs/component';
import { HandlerCaller, getHandler, getRegistry } from '../handlerutils';

export function execute(componentName?: string, componentId?: string, handler?: string, registry?: string) {

  common.requireZoweYaml();
  const ZOWE_CONFIG=config.getZoweConfig();

  if (componentName) {
    const componentDir = component.findComponentDirectory(componentName);
    
    if (componentDir) {
      const manifest = component.getManifest(componentDir);
      const enabled=ZOWE_CONFIG.components[componentName] && ZOWE_CONFIG.components[componentName].enabled === true;
      common.printMessage(`Component ${manifest.name} ${manifest.id ? '('+manifest.id+')' : ''} status: ${enabled ? 'ENABLED' : 'DISABLED'} ${manifest.version ? 'version: '+manifest.version : ''} `);
    } else {
      common.printMessage(`Component ${componentName} status: UNINSTALLED`);
    }
  } else if (!componentId) {
    common.printErrorAndExit("Error ZWEL0310E: Component name (-name|-n) or id (-id,-d) required but not specified.", undefined, 310);
  }

  handler = getHandler(handler);
  if (!handler) {
    common.printErrorAndExit("Error ZWEL0311E: Handler (-handler,-h or zowe.extensionRegistry.defaultHandler) required but not specified.", undefined, 311);
  }
  registry = getRegistry(handler, registry);  
  const handlerCaller = new HandlerCaller(handler, registry);

  handlerCaller.search(componentName);
}
