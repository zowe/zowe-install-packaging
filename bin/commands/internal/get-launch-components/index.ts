/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as common from '../../../libs/common';
import * as config from '../../../libs/config';

export function execute(): string {
  common.requireZoweYaml();

  //TODO dont really need to do this if i can just use component.findAllLaunchComponents()
  config.loadEnvironmentVariables();

  const components = std.getenv('ZWE_LAUNCH_COMPONENTS');
  common.printMessage(components);
  return components;
}
