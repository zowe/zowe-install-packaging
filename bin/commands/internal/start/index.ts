/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as os from 'cm_os';
import * as zos from 'zos';
import * as common from '../../../libs/common';
import * as internalStartPrepare from './prepare/index';
import * as internalStartComponent from './component/index';

export function execute() {
  // Validation
  common.requireZoweYaml();

  // prepare instance/.env and instance/workspace directories
  internalStartPrepare.execute();

  if (std.getenv('ZWE_PRIVATE_CONTAINER_COMPONENT_ID')) {
    internalStartComponent.execute(std.getenv("ZWE_PRIVATE_CONTAINER_COMPONENT_ID"), false);
    //TODO ensure this waits
  } else {
    const launchComponents = std.getenv("ZWE_LAUNCH_COMPONENTS").split(',');
    launchComponents.forEach(function(componentName:string) {
      internalStartComponent.execute(componentName, true);
    });
  }
}
