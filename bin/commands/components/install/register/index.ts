/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as appfwRegister from './appfw/index';
import * as zisRegister from './zis/index';

export function execute(componentName: string, zisPluginDatasets?: string[], dryRun?: boolean) {
  appfwRegister.execute(componentName, dryRun);
  zisRegister.execute(componentName, zisPluginDatasets, dryRun);
}
