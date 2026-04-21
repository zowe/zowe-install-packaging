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
import * as component from '../../../libs/component';

const COMMAND_NAME = 'zwe-validate-components';

/**
 * Validates that components listed in the zowe.yaml components section
 * have a valid manifest file (manifest.yaml, manifest.yml, or manifest.json).
 *
 * @param quitOnError      - When true, exits the process on failure. When false,
 *                           logs a warning and returns a non-zero exit code.
 * @param componentNames   - Optional comma-separated list of component IDs to check.
 *                           When omitted, only enabled components are checked - disabled
 *                           components that are missing a directory or manifest are not an error.
 * @returns 0 on success or a number corresponding to the issue encountered.
 */
export function execute(quitOnError?: boolean, componentNames?: string): number {
  common.requireZoweYaml();
  const ZOWE_CONFIG = config.getZoweConfig();

  if (!ZOWE_CONFIG.zowe.runtimeDirectory) {
    const errMsg = `ZWEL0332E: Zowe YAML property zowe.runtimeDirectory is not defined. Zowe cannot validate component existence without knowing the runtime location.`;
    if (quitOnError) {
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, errMsg);
      std.exit(332);
    } else {
      common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME, errMsg.replace('ZWEL0332E', 'ZWEL0332W'));
      return 332;
    }
  }

  const allComponents = ZOWE_CONFIG.components ? Object.keys(ZOWE_CONFIG.components) : [];

  if (allComponents.length === 0) {
    const errMsg = `ZWEL0329E: No components are defined in zowe.yaml. Zowe cannot start without at least one component.`;
    if (quitOnError) {
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, errMsg);
      std.exit(329);
    } else {
      common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME, errMsg.replace('ZWEL0329E', 'ZWEL0329W'));
      return 329;
    }
  }

  // Determine which components to validate
  let checkedComponents: string[];
  if (componentNames && componentNames.trim().length > 0) {
    const requested = componentNames.split(',').map(s => s.trim()).filter(s => s.length > 0);
    const notInYaml = requested.filter(id => !allComponents.includes(id));
    if (notInYaml.length > 0) {
      const errMsg = `ZWEL0331${quitOnError ? 'E' : 'W'}: The following requested component(s) are not defined in zowe.yaml: ${notInYaml.join(', ')}`;
      if (quitOnError) {
        common.printFormattedError(common.MSG_KEY, COMMAND_NAME, errMsg);
        std.exit(331);
      } else {
        common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME, errMsg);
        return 331;
      }
    }
    checkedComponents = requested;
  } else {
    // When no specific components are requested, only check enabled ones.
    // Disabled components that are missing a directory or manifest are not an error.
    checkedComponents = allComponents.filter(id => ZOWE_CONFIG.components[id]?.enabled === true);
  }

  common.printFormattedInfo(common.MSG_KEY, COMMAND_NAME, `Validating manifests for ${checkedComponents.length} component(s).`);

  const invalidComponents: string[] = [];

  for (const componentId of checkedComponents) {
    const componentDir = component.findComponentDirectory(componentId);
    if (!componentDir) {
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME,
        `ZWEL0330E: Component '${componentId}' directory was not found in the runtime or extension directories.`);
      invalidComponents.push(componentId);
      continue;
    }

    const manifestPath = component.getManifestPath(componentDir);
    if (!manifestPath) {
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME,
        `ZWEL0333E: Component '${componentId}' is missing a valid manifest file (manifest.yaml, manifest.yml, or manifest.json) in ${componentDir}.`);
      invalidComponents.push(componentId);
    } else {
      common.printFormattedDebug(common.MSG_KEY, COMMAND_NAME, `Component '${componentId}' manifest found at ${manifestPath}.`);
    }
  }

  if (invalidComponents.length > 0) {
    const errMsg = `ZWEL0328${quitOnError ? 'E' : 'W'}: The following component(s) are missing a valid manifest file and cannot be started: ${invalidComponents.join(', ')}`;
    if (quitOnError) {
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, errMsg);
      std.exit(328);
    } else {
      common.printFormattedWarn(common.MSG_KEY, COMMAND_NAME, errMsg);
      return 328;
    }
  }

  common.printFormattedInfo(common.MSG_KEY, COMMAND_NAME, `All checked component(s) have valid manifest files.`);
  return 0;
}
