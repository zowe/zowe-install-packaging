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
import * as fs from '../../../../libs/fs';
import * as zoslib from '../../../../libs/zos';
import * as common from '../../../../libs/common';
import * as stringlib from '../../../../libs/string';
import * as node from '../../../../libs/node';
import * as shell from '../../../../libs/shell';
import * as config from '../../../../libs/config';
import * as component from '../../../../libs/component';

export function execute() {
  node.requireNode();

  let pod_name = shell.execOutSync('hostname', '-s').out?.toLowerCase();
  
  common.printLevel0Message('Delete APIML static definitions written by current pod ' + pod_name);
  // Validation
  common.requireZoweYaml();

  //load environment
  config.loadEnvironmentVariables();

  if (!std.getenv('ZWE_RUN_IN_CONTAINER')){
    common.printErrorAndExit('Error ZWEL0123E: This function is only available in Zowe Containerization deployment.', undefined, 157);
  }
  
  let zwe_static_definition_dir = std.getenv('ZWE_STATIC_DEFINITIONS_DIR');
  let zwe_cli_parameter_hs_instance = std.getenv('ZWE_CLI_PARAMETER_HA_INSTANCE');
  if(fs.directoryExists(zwe_static_definition_dir) && pod_name !== undefined){
    let result = shell.execOutSync('sh', '-c', `cd ${zwe_cli_parameter_hs_instance} && ls -l 2>&1`);
    if (result.out) {
      common.printMessage("- deleting");
      shell.execOutSync('sh', '-c', `rm -f *.${zwe_cli_parameter_hs_instance}.* 2>&1`);
      common.printMessage("- refreshing api catalog");
      let apicatalog_host = `api-catalog-service.${std.getenv('ZWE_POD_NAMESPACE')? std.getenv('ZWE_POD_NAMESPACE'): 'zowe'}.svc.${std.getenv('ZWE_POD_CLUSTERNAME')? std.getenv('ZWE_POD_CLUSTERNAME'): 'cluster.local'}`
      component.refreshStaticRegistration(apicatalog_host,
      std.getenv('ZWE_components_api_catalog_port'),
      std.getenv('ZWE_zowe_certificate_pem_key'),
      std.getenv('ZWE_zowe_certificate_pem_certificate'),
      std.getenv('ZWE_zowe_certificate_pem_certificateAuthorities'));
      if (success) {
        common.printFormattedDebug("ZWELS", "zwe-internal-start-prepare,configure_components", `${componentName} processComponentDiscoverySharedLibs success`);
      } else {
        common.printFormattedError("Error ZWEL0142E", "zwe-internal-start-prepare,configure_components", `${componentName} processComponentDiscoverySharedLibs failure`);
      }
    } else {
      common.printMessage("- nothing to delete");    }
  }
}


  // exit message
  common.printLevel1Message(`APIML static registrations are refreshed successfully.`);
}