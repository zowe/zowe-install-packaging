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

import * as common from '../../../libs/common';
import * as component from '../../../libs/component';
import * as jsonlib from '../../../libs/json';
import * as configmgr from '../../../libs/configmgr';

export function execute(componentId: string, haInstance?: string, dryRun?: boolean) {
  common.requireZoweYaml();

  const componentArg = std.getenv('ZWE_CLI_PARAMETER_COMPONENT_FILE');
  let dryRunDir;
  if (componentArg && fs.directoryExists(componentArg) && dryRun) {
    dryRunDir = componentArg;
  }
  
  const componentDir = component.findComponentDirectory(componentId);

  if (!componentDir || (dryRun && !dryRunDir)) {
    common.printErrorAndExit(`Error ZWEL0152E: Cannot find component ${componentId}.`, undefined, 152);
  }

  let componentConfigPath:string;

  const zoweConfig = configmgr.getZoweConfig();
  if (haInstance) {
    componentConfigPath = `haInstances.${haInstance}.components.${componentId}`;
    if (zoweConfig.haInstances &&
        zoweConfig.haInstances[haInstance] &&
        zoweConfig.haInstances[haInstance].components &&
        zoweConfig.haInstances[haInstance].components[componentId]) {
      common.printMessage(`HA Property is currently ${zoweConfig.haInstances[haInstance].components[componentId].enabled}`);
    } else {
      common.printMessage(`HA Property is currently undefined`);
    }
    if (zoweConfig.components[componentId]) {
      common.printMessage(`Global property is currently ${zoweConfig.components[componentId].enabled}`);
    } else {
      common.printMessage(`Global property is currently undefined`);
    }
    common.printMessage(`Setting property ${componentConfigPath}.enabled to true`);

  } else {
    componentConfigPath = `components.${componentId}`;
    if (zoweConfig.components[componentId]) {
      common.printMessage(`Global property is currently ${zoweConfig.components[componentId].enabled}`);
    } else {
      common.printMessage(`Global property is currently undefined`);
    }
    common.printMessage(`Setting property ${componentConfigPath}.enabled to true`);
  }

  const firstConfigFile = configmgr.getFirstConfigFile();
  common.printMessage(`Setting ${componentConfigPath}.enabled: true`);

  
  if (!dryRun) {
    common.printMessage(`Updating ${firstConfigFile}`);
    jsonlib.updateZoweYaml(firstConfigFile, `${componentConfigPath}.enabled`, true);
  } else {
    common.printMessage(`Dry-run mode, YAML not updated.`);
  }
}
