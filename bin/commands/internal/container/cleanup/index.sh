#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.
################################################################################

################################################################################
# This utility script will validate component instances defined in static
# definitions. If the instance is not presented any more, the static definition
# will be removed.
#
# Note: this utility requires node.js.
################################################################################

set +e

print_level0_message "Clean up outdated static definitions"

################################################################################
# Constants and variables
ZWE_STATIC_DEFINITIONS_DIR=${ZWE_PRIVATE_CONTAINER_WORKSPACE_DIRECTORY}/api-mediation/api-defs
# dns resolution cool down minutes
POD_DNS_COOL_DOWN=15

################################################################################
# Functions
check_instance() {
  result=$(node "${ZWE_zowe_runtimeDirectory}"/bin/utils/curl.js "$1" -k 2>&1 | grep -E '(ENOTFOUND|EHOSTUNREACH)')
  if [ -n "${result}" ]; then
    print_message "    - ${result}"
    return 1
  fi
}
 
###############################
# validation
require_node

# check static definitions
modified=
for one in $(find "${ZWE_STATIC_DEFINITIONS_DIR}" -type f -mmin "+${POD_DNS_COOL_DOWN}"); do
  print_message "> Validating ${one}"
  instance_urls=$(read_yaml "${one}" ".services[].instanceBaseUrls[]" 2>/dev/null)
  if [ -n "${instance_urls}" ]; then
    for url in ${instance_urls}; do
      print_message "  - ${url}"
      check_instance "${url}"
      if [ $? -gt 0 ]; then
        rm -f "${one}"
        print_message "    * invalid and removed"
        modified=true
      else
        print_message "    * valid"
      fi
    done
  fi
  print_message
done

# refresh static definition services
if [ "${modified}" = "true" ]; then
  print_level1_message "Refreshing static definitions"
  refresh_static_registration \
    api-catalog-service.${ZWE_POD_NAMESPACE:-zowe}.svc.${ZWE_POD_CLUSTERNAME:-cluster.local} \
    7552 \
    ${ZWE_PRIVATE_CONTAINER_KEYSTORE_DIRECTORY}/keystore.key \
    ${ZWE_PRIVATE_CONTAINER_KEYSTORE_DIRECTORY}/keystore.cer \
    ${ZWE_PRIVATE_CONTAINER_KEYSTORE_DIRECTORY}/ca.cer || true
  print_message
fi

###############################
# exit message
print_level1_message "APIML static registrations are cleaned up successfully."
