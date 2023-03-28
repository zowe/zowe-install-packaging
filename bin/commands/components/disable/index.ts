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
import * as component from '../../../libs/component';
import * as jsonlib from '../../../libs/json';

export function execute(componentId: string, haInstance?: string) {
  common.requireZoweYaml();

  const componentDir = component.findComponentDirectory(componentId);

  if (!componentDir) {
    common.printErrorAndExit(`Error ZWEL0152E: Cannot find component ${componentId}.`, undefined, 152);
  }

  const componentConfigPath = haInstance
        ? `haInstances.${haInstance}.components.${componentId}`
        : `components.${componentId}`

  jsonlib.updateZoweYaml(std.getenv("ZWE_CLI_PARAMETER_CONFIG"), `${componentConfigPath}.enabled`, false);
}
