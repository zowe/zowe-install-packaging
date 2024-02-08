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

print_level1_message "Create VSAM storage for Zowe Caching Service"

###############################
# constants

###############################
# validation
require_zowe_yaml

caching_storage=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".components.caching-service.storage.mode" | upper_case)
if [ "${caching_storage}" != "VSAM" ]; then
  print_error "Warning ZWEL0301W: Zowe Caching Service is not configured to use VSAM. Command skipped."
  return 0
fi
# read prefix and validate
prefix=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.prefix")
if [ -z "${prefix}" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file." "" 157
fi

jcllib=$(verify_generated_jcl)

required_yaml_content="mode volume storageClass name"

for key in ${required_params}; do
  eval "${key}=$(read_yaml \"${ZWE_CLI_PARAMETER_CONFIG}\" \".zowe.setup.vsam.${key}\")"
  if [ -z "${key}" ]; then
      print_error_and_exit "Error ZWEL0157E: VSAM parameter (zowe.setup.vsam.${key}) is not defined in Zowe YAML configuration file." "" 157
  fi
done

# VSAM cache cannot be overwritten, must delete manually
# FIXME: cat cannot be used to test VSAM data set
vsam_existence=$(is_data_set_exists "${name}")
if [ "${vsam_existence}" = "true" ]; then
  if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}" = "true" ]; then
    # delete blindly and ignore errors
    result=$(tso_command delete "'${name}'")
  else
    # error
    print_error_and_exit "Error ZWEL0158E: ${name} already exists." "" 158
  fi
fi


###############################
# execution (or dry-run)

print_and_handle_jcl "//'${jcllib}(ZWECSVSM)" "ZWECSVSM" "${jcllib}" "${prefix}"
if [ -z "${ZWE_CLI_PARAMETER_DRY_RUN}" ]; then
  print_level2_message "Zowe Caching Service VSAM storage is created successfully."
  if [ "${ZWE_CLI_PARAMETER_UPDATE_CONFIG}" = "true" ]; then
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "components.caching-service.storage.vsam.name" "${name}"
    print_level2_message "Zowe configuration is updated successfully."
  fi
fi
