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

export function execute(componentFile: string, autoEncoding?:string, skipEnable?:boolean) {
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
