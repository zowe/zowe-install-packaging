#!/bin/sh

#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.
#######################################################################

export ZWE_PRIVATE_CONTAINER_HOME_DIRECTORY=/home/zowe
export ZWE_PRIVATE_CONTAINER_RUNTIME_DIRECTORY=/home/zowe/runtime
export ZWE_PRIVATE_CONTAINER_COMPONENT_RUNTIME_DIRECTORY=/component
export ZWE_PRIVATE_CONTAINER_WORKSPACE_DIRECTORY=/home/zowe/instance/workspace
export ZWE_PRIVATE_CONTAINER_LOG_DIRECTORY=/home/zowe/instance/logs
export ZWE_PRIVATE_CONTAINER_KEYSTORE_DIRECTORY=/home/zowe/keystore

# prepare all environment variables used in containerization
# these variables shouldn't be modified
prepare_container_runtime_environments() {
  # to fix issues:
  # - https://github.com/zowe/api-layer/issues/1768
  # - https://github.com/spring-cloud/spring-cloud-netflix/issues/3941
  # if you run Gateway on mainframe or locally, it will register with eureka health status - that is UP or DOWN, but
  # in kubernetes, Gateway creates 2 additional health indicators and they are causing this OUT_OF_SERVICE, but this
  # status is coming from spring, not from eureka
  export MANAGEMENT_ENDPOINT_HEALTH_PROBES_ENABLED=false

  if [ -z "${ZWE_POD_NAMESPACE}" -a -f /var/run/secrets/kubernetes.io/serviceaccount/namespace ]; then
    # try to detect ZWE_POD_NAMESPACE, this requires automountServiceAccountToken to be true
    ZWE_POD_NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace 2>/dev/null)
  fi
  if [ -z "${ZWE_POD_NAMESPACE}" ]; then
    # fall back to default value
    export ZWE_POD_NAMESPACE=zowe
  fi
  if [ -z "${ZWE_POD_CLUSTERNAME}" ]; then
    # fall back to default value
    export ZWE_POD_CLUSTERNAME=cluster.local
  fi

  # read ZWE_PRIVATE_CONTAINER_COMPONENT_ID from component manifest
  # /component is hardcoded path we asked for in conformance
  if [ -z "${ZWE_PRIVATE_CONTAINER_COMPONENT_ID}" ]; then
    export ZWE_PRIVATE_CONTAINER_COMPONENT_ID=$(read_component_manifest /component '.name')
  fi

  # in kubernetes, replace ZWE_haInstance_hostname with pod dns name
  host_name=$(get_sysname)
  host_ip=$(get_ipaddress "${host_name}")
  export ZWE_haInstance_hostname="$(echo "${host_ip}" | sed -e 's#\.#-#g').${ZWE_POD_NAMESPACE}.pod.${ZWE_POD_CLUSTERNAME}"

  # kubernetes gateway service internal dns name
  export GATEWAY_HOST=gateway-service.${ZWE_POD_NAMESPACE}.svc.${ZWE_POD_CLUSTERNAME}
  export ZWE_GATEWAY_HOST=${GATEWAY_HOST}

  # overwrite ZWE_DISCOVERY_SERVICES_LIST from ZWE_DISCOVERY_SERVICES_REPLICAS
  ZWE_DISCOVERY_SERVICES_REPLICAS=$(echo "${ZWE_DISCOVERY_SERVICES_REPLICAS}" | tr -cd '[[:digit:]]' | tr -d '[[:space:]]')
  if [ -z "${ZWE_DISCOVERY_SERVICES_REPLICAS}" ]; then
    export ZWE_DISCOVERY_SERVICES_REPLICAS=1
  fi
  discovery_index=0
  export ZWE_DISCOVERY_SERVICES_LIST=
  while [ $discovery_index -lt ${ZWE_DISCOVERY_SERVICES_REPLICAS} ]; do
    if [ -n "${ZWE_DISCOVERY_SERVICES_LIST}" ]; then
      ZWE_DISCOVERY_SERVICES_LIST="${ZWE_DISCOVERY_SERVICES_LIST},"
    fi
    ZWE_DISCOVERY_SERVICES_LIST="${ZWE_DISCOVERY_SERVICES_LIST}https://discovery-${discovery_index}.discovery-service.${ZWE_POD_NAMESPACE}.svc.${ZWE_POD_CLUSTERNAME}:${ZWE_components_discovery_port}/eureka/"
    discovery_index=`expr $discovery_index + 1`
  done

  # overwrite component list variables
  export ZWE_INSTALLED_COMPONENTS="${ZWE_PRIVATE_CONTAINER_COMPONENT_ID}"
  export ZWE_ENABLED_COMPONENTS="${ZWE_PRIVATE_CONTAINER_COMPONENT_ID}"
  export ZWE_LAUNCH_COMPONENTS="${ZWE_PRIVATE_CONTAINER_COMPONENT_ID}"

  # FIXME: below variables are different from HA configuration, we should consolidate and make them consistent
  # in HA setup, this is used to point where is gateway accessible from internal
  # export EUREKA_INSTANCE_HOMEPAGEURL=https://${GATEWAY_HOST}:${GATEWAY_PORT}/
  unset EUREKA_INSTANCE_HOMEPAGEURL
}
