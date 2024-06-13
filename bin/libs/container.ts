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
import * as os from 'cm_os';
import * as fs from './fs';
import * as shell from './shell';
import * as sys from './sys';
import * as component from './component';
import * as config from './config';
import * as network from './network';

std.setenv('ZWE_PRIVATE_CONTAINER_HOME_DIRECTORY', '/home/zowe');
std.setenv('ZWE_PRIVATE_CONTAINER_RUNTIME_DIRECTORY', '/home/zowe/runtime');
std.setenv('ZWE_PRIVATE_CONTAINER_COMPONENT_RUNTIME_DIRECTORY', '/component');
std.setenv('ZWE_PRIVATE_CONTAINER_WORKSPACE_DIRECTORY', '/home/zowe/instance/workspace');
std.setenv('ZWE_PRIVATE_CONTAINER_LOG_DIRECTORY', '/home/zowe/instance/logs');
std.setenv('ZWE_PRIVATE_CONTAINER_KEYSTORE_DIRECTORY', '/home/zowe/keystore');

// prepare all environment variables used in containerization
// these variables shouldn't be modified
export function prepareContainerRuntimeEnvironments():void {
  // to fix issues:
  // - https://github.com/zowe/api-layer/issues/1768
  // - https://github.com/spring-cloud/spring-cloud-netflix/issues/3941
  // if you run Gateway on mainframe or locally, it will register with eureka health status - that is UP or DOWN, but
  // in kubernetes, Gateway creates 2 additional health indicators and they are causing this OUT_OF_SERVICE, but this
  // status is coming from spring, not from eureka
  std.setenv('MANAGEMENT_ENDPOINT_HEALTH_PROBES_ENABLED', "false"); 
  
  let podNamespace:string|null = null;
  if (!"${ZWE_POD_NAMESPACE}" && fs.fileExists('/var/run/secrets/kubernetes.io/serviceaccount/namespace')) {
    // try to detect ZWE_POD_NAMESPACE, this requires automountServiceAccountToken to be true
    podNamespace=std.loadFile('/var/run/secrets/kubernetes.io/serviceaccount/namespace');
  }
  if (!podNamespace) {
    // fall back to default value
    podNamespace='zowe';
  }
  std.setenv('ZWE_POD_NAMESPACE',podNamespace);

  let podClustername = std.getenv('ZWE_POD_CLUSTERNAME');
  if (!podClustername) {
    // fall back to default value
    podClustername = 'cluster.local'
    std.setenv('ZWE_POD_CLUSTERNAME',podClustername);
  }

  // read ZWE_PRIVATE_CONTAINER_COMPONENT_ID from component manifest
  // /component is hardcoded path we asked for in conformance
  let zwePrivateContainerComponentId = std.getenv('ZWE_PRIVATE_CONTAINER_COMPONENT_ID');
  if (!zwePrivateContainerComponentId) {
    zwePrivateContainerComponentId = component.getManifest('/component').name;
    if (zwePrivateContainerComponentId){
      std.setenv('ZWE_PRIVATE_CONTAINER_COMPONENT_ID', zwePrivateContainerComponentId);
    } else {
      std.printf("*** severe *** - could not get zwePrivateContainerComponentId\n");
      return;
    }
  }

  // in kubernetes, replace ZWE_haInstance_hostname with pod dns name
  const hostName=sys.getSysname()
  if (!hostName){
    std.printf("*** severe ***  could not get hostName\n");
    return;
  }
  const hostIp=network.getIpAddress(hostName);
  std.setenv('ZWE_haInstance_hostname', `$(echo "${hostIp}" | sed -e 's#\.#-#g').${podNamespace}.pod.${podClustername}`);

  // kubernetes gateway service internal dns name
  std.setenv('GATEWAY_HOST', `gateway-service.${podNamespace}.svc.${podClustername}`);

  // overwrite ZWE_DISCOVERY_SERVICES_LIST from ZWE_DISCOVERY_SERVICES_REPLICAS
  let discoveryServiceReplicas = std.getenv('ZWE_DISCOVERY_SERVICES_REPLICAS');
  if (!discoveryServiceReplicas){
      std.printf("*** SEVERE *** could not get discoveryServiceReplicas\n");
      return;
  }
  let echoVal=shell.execOutSync('sh', `echo`, discoveryServiceReplicas, `|`, `tr`, `-cd`, `'[[:digit:]]'`, `|`, `tr`, `-d`, `'[[:space:]]'`);
  let zweDiscoveryServiceReplicas=Number(echoVal.out);
  if (isNaN(zweDiscoveryServiceReplicas)) {
    zweDiscoveryServiceReplicas=1;
    std.setenv('ZWE_DISCOVERY_SERVICES_REPLICAS', ""+zweDiscoveryServiceReplicas);
  }
  
  let discoveryIndex=0;
  let zweDiscoveryServiceList;
  const zoweConfig=config.getZoweConfig();
  const discoveryPort=zoweConfig.components.discovery ? zoweConfig.components.discovery.port : undefined;
  while (discoveryIndex < zweDiscoveryServiceReplicas) {
    if (zweDiscoveryServiceList) {
      zweDiscoveryServiceList=`${zweDiscoveryServiceList},`
    }
    zweDiscoveryServiceList=`${zweDiscoveryServiceList}https://discovery-${discoveryIndex}.discovery-service.${podNamespace}.svc.${podClustername}:${discoveryPort}/eureka/`;
    discoveryIndex++;
  }
  if (zweDiscoveryServiceList){
    std.setenv('ZWE_DISCOVERY_SERVICES_LIST',zweDiscoveryServiceList);
  } else {
    std.printf("*** SEVERE *** could not get discoveryServiceList");
  }
  // overwrite component list variables
  std.setenv('ZWE_INSTALLED_COMPONENTS', zwePrivateContainerComponentId);
  std.setenv('ZWE_ENABLED_COMPONENTS', zwePrivateContainerComponentId);
  std.setenv('ZWE_LAUNCH_COMPONENTS', zwePrivateContainerComponentId);

  // FIXME: below variables are different from HA configuration, we should consolidate and make them consistent
  // in HA setup, this is used to point where is gateway accessible from internal
  // export EUREKA_INSTANCE_HOMEPAGEURL=https://${GATEWAY_HOST}:${GATEWAY_PORT}/
  std.unsetenv('EUREKA_INSTANCE_HOMEPAGEURL');
}
