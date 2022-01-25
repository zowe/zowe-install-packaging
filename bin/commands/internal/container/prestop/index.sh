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

#######################################################################
# Constants
POD_NAME=$(hostname -s 2>/dev/null)

print_level0_message "Delete APIML static definitions written by current pod ${POD_NAME}"

###############################
# validation
require_zowe_yaml
# load environment
load_environment_variables

if [ "${ZWE_RUN_IN_CONTAINER}" != "true" ]; then
  print_error_and_exit "Error ZWEL0123E: This function is only available in Zowe Containerization deployment." "" 123
fi

#######################################################################
if [ -d "${ZWE_STATIC_DEFINITIONS_DIR}" -a -n "${POD_NAME}" ]; then
  cd "${ZWE_STATIC_DEFINITIONS_DIR}"

  print_message "- listing ${ZWE_STATIC_DEFINITIONS_DIR}"
  files=$(ls -l *.${ZWE_CLI_PARAMETER_HA_INSTANCE}.* 2>/dev/null || true)
  if [ -n "${files}" ]; then
    print_message "- deleting"
    rm -f *.${ZWE_CLI_PARAMETER_HA_INSTANCE}.*

    print_message "- refreshing api catalog"
    refresh_static_registration \
      api-catalog-service.${ZWE_POD_NAMESPACE:-zowe}.svc.${ZWE_POD_CLUSTERNAME:-cluster.local} \
      ${ZWE_components_api_catalog_port} \
      "${ZWE_zowe_certificate_pem_key}" \
      "${ZWE_zowe_certificate_pem_certificate}" \
      "${ZWE_zowe_certificate_pem_certificateAuthorities}" || true
  else
    print_message "- nothing to delete"
  fi
fi

###############################
# exit message
print_level1_message "APIML static registrations are refreshed successfully."
