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
import * as common from '../../../../../../libs/common';
import * as stringlib from '../../../../../../libs/string';
import * as config from '../../../../../../libs/config';
import * as component from '../../../../../../libs/component';
import { PathAPI as pathoid } from '../../../../../../libs/pathoid';

export function execute(componentName?: string, zisPluginDatasets?: string[], dryRun?: boolean) {
  common.requireZoweYaml();

  if (zisPluginDatasets) {
    let success = component.addZisLoadLibToStcJcl(zisPluginDatasets, dryRun);
    if (!success) {
      common.printErrorAndExit(`ZIS plugin installation failed.`);
    }
  } else if (!componentName) {
    common.printErrorAndExit(`Input component name (-o) or ZIS plugin datasets (-z) required`);
  } else {
    
  }





  const ZOWE_CONFIG=config.getZoweConfig();
  // read extensionDirectory
  const extensionDir=ZOWE_CONFIG.zowe.extensionDirectory;
  if (!extensionDir) {
    common.printErrorAndExit("Error ZWEL0180E: Zowe extension directory (zowe.extensionDirectory) is not defined in Zowe YAML configuration file.", undefined, 180);
  }

  const targetDir = stringlib.removeTrailingSlash(extensionDir);
  const componentDir = pathoid.join(targetDir, componentName);


  const manifest = component.getManifest(componentDir);
  if (manifest.zisPlugins) {
    if (os.platform != 'zos') {
      common.printErrorAndExit(`ZIS plugin installation must be done on z/OS. Rerun commmand on a Zowe instance on z/OS to complete install`, undefined, 999);
      
    } else {
      if (zisPluginDatasets) {
        let success = component.addZisLoadLibToStcJcl(zisPluginDatasets, dryRun);
        if (!success) {
          common.printErrorAndExit(`ZIS plugin installation failed.`);
        }
      } else {
        component.copyZisPluginsToAuthLoadLib(zisPlugins, dryRun);
      }
    }
  } else {
    common.printDebug(`Component ${componentName} does not have ZIS plugins, action skipped`);
  }
}
