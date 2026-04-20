/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as common from './common';
import * as config from './config';
import * as component from './component';
import * as shell from './shell';

const INDIVIDUAL_APIML_COMPONENTS = ['gateway', 'discovery', 'api-catalog', 'caching-service', 'zaas'];

export function validateAttlsPorts(quitOnError?: boolean): number {
  common.requireZoweYaml();
  let hasErrors = false;
  const ZOWE_CONFIG = config.getZoweConfig();
  let enabledComponents = component.getEnabledComponents().filter(name => !!ZOWE_CONFIG.components[name].port);
  if (enabledComponents.includes('apiml')) {
    enabledComponents = enabledComponents.filter(name => !INDIVIDUAL_APIML_COMPONENTS.includes(name));
  }

  const myJobname = std.getenv('_BPX_JOBNAME');
  const globalAttlsEnabled = ZOWE_CONFIG.zowe.network?.server?.tls?.attls;
  const globalListenAddress = ZOWE_CONFIG.zowe.network?.server?.listenAddresses[0]
    ? ZOWE_CONFIG.zowe.network.server.listenAddresses[0]
    : '0.0.0.0';
  
  let componentConfigs = enabledComponents.map((name)=> {
    let componentManifest: any;
    const componentDir = component.findComponentDirectory(name);
    if (componentDir) {
      componentManifest = component.getManifest(componentDir);
    }

    const jobname = component.getJobnameForComponent(name, componentManifest);
    const attlsEnabled = ZOWE_CONFIG.components[name].zowe?.network?.server?.tls?.attls !== undefined
      ? ZOWE_CONFIG.components[name].zowe?.network?.server?.tls?.attls
      : globalAttlsEnabled

    // Get listen address
    const listenAddress = ZOWE_CONFIG.components[name].zowe?.network?.server?.listenAddresses
      ? ZOWE_CONFIG.components[name].zowe.network.server.listenAddresses[0]
      : globalListenAddress;
    
    if (name == 'apiml') {
      let ports = [ZOWE_CONFIG.components.discovery?.port, ZOWE_CONFIG.components.gateway?.port];
      if (ZOWE_CONFIG.components['caching-service']?.storage?.mode == 'infinispan') {
        ports.push(ZOWE_CONFIG.components['caching-service'].storage.infinispan.jgroups.port);
        ports.push(ZOWE_CONFIG.components['caching-service'].storage.infinispan.jgroups.keyExchange.port);
      }
      return {
        listenAddress: listenAddress, 
        name: name,
        ports: ports,
        jobname: jobname,
        attlsEnabled: attlsEnabled
      }
    } else if (name == 'caching-service') {
      let ports = [ZOWE_CONFIG.components[name].port];
      if (ZOWE_CONFIG.components['caching-service']?.storage?.mode == 'infinispan') {
        ports.push(ZOWE_CONFIG.components['caching-service'].storage.infinispan.jgroups.port);
        ports.push(ZOWE_CONFIG.components['caching-service'].storage.infinispan.jgroups.keyExchange.port);
      }

      return {
        listenAddress: listenAddress, 
        name: name,
        ports: [ports],
        jobname: jobname,
        attlsEnabled: attlsEnabled
      }
    } else {
      return {
        listenAddress: listenAddress, 
        name: name,
        ports: [ZOWE_CONFIG.components[name].port],
        jobname: jobname == '' ? myJobname : jobname,
        attlsEnabled: attlsEnabled
      }

    }
  });

  const zoweUserId = common.getUserId();

  let detectAttlsPortPath = std.getenv('ZWE_zowe_runtimeDirectory') + '/bin/utils/attls-test';


  common.printFormattedInfo(common.MSG_KEY, 'validateAttlsPorts', `Checking ATTLS state of ${Object.keys(componentConfigs).length} enabled components with ports`);
  let failedCount = 0;
  
  componentConfigs.forEach((component)=> {
    // ATTLS direction is hardcoded to Inbound (1) for now
    let attlsDirection = 1; // Inbound

    component.ports.forEach((port) => {

      std.setenv('_BPX_JOBNAME', component.jobname);
      common.printFormattedDebug(common.MSG_KEY, 'validateAttlsPorts', 
        `${component.name}: Checking if ATTLS is enabled for port ${port} for userid ${zoweUserId} on host ${component.listenAddress}, jobname ${component.jobname}`);
      
      // Call attls-test binary
      let result = shell.execOutSync(detectAttlsPortPath, 
                                     '--serverPort', port.toString(), 
                                     '--serverHost', component.listenAddress,
                                     '--direction', attlsDirection.toString());
      
      // restore original jobname
      std.setenv('_BPX_JOBNAME', myJobname);

      // Check for mismatch: ATTLS enabled in config but no rules found, or ATTLS not enabled but rules found
      if (component.attlsEnabled && result.rc) {
        // ATTLS is enabled but no rules found
        failedCount++;
        if (result.out) {
          common.printDebug(result.out);
        }
        common.printFormattedError(common.MSG_KEY, 'validateAttlsPorts', 
          `ZWEL0365E: ${component.name}: No AT-TLS rule identified on ${component.listenAddress}:${port} for user ${zoweUserId} and jobname ${component.jobname}`);
        hasErrors = true;
      } else if (!component.attlsEnabled && !result.rc) {
        // ATTLS is not enabled but rules are found - configuration mismatch
        failedCount++;
        if (result.out) {
          common.printDebug(result.out);
        }
        common.printFormattedError(common.MSG_KEY, 'validateAttlsPorts',
          `ZWEL0367E: ${component.name}: AT-TLS rule found but ATTLS is not enabled in configuration on ${component.listenAddress}:${port} for user ${zoweUserId} and jobname ${component.jobname}`);

        hasErrors = true;
      } else if (result.out) {
        common.printDebug(result.out);
      }
    });
  });

  if (!hasErrors) {
    common.printFormattedInfo(common.MSG_KEY, 'validateAttlsPorts', `Zowe port ATTLS validation passed.`);
    return 0;
  } else if (!quitOnError) {
    common.printFormattedError(common.MSG_KEY, 'validateAttlsPorts', 
      `ZWEL0366E: ${failedCount} Zowe port ATTLS validation(s) failed, review output for action items before running Zowe.`);
    return failedCount;
  } else {
    // It is possible that the ATTLS check failed due to missing attls-test binary or other unexpected error, so we want to provide a hint about how to bypass the check if needed instead of just exiting with error code.
    common.printFormattedError(common.MSG_KEY, 'validateAttlsPorts',
      `Zowe port ATTLS validation failed. This check can be dismissed with YAML value "zowe.launchScript.startupChecks.attls: warn"`);
    common.printErrorAndExit(
      `ZWEL0366E: ${failedCount} Zowe port ATTLS validation(s) failed, review output for action items before running Zowe.`, 
      undefined, 8);
    return failedCount;
  }
}
