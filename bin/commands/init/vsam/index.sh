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

USE_CONFIGMGR=$(check_configmgr_enabled)
if [ "${USE_CONFIGMGR}" = "true" ]; then
  if [ -z "${ZWE_PRIVATE_TMP_MERGED_YAML_DIR}" ]; then

    # user-facing command, use tmpdir to not mess up workspace permissions
    export ZWE_PRIVATE_TMP_MERGED_YAML_DIR=1
  fi
  _CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/init/vsam/cli.js"
else
  print_error_and_exit "Error ZWEL0316E: Command requires zowe.useConfigmgr=true to use." "" 316
fi


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
if [ "$?" -eq 1 ]; then
  print_error_and_exit "Error ZWEL0999E: zowe.setup.dataset.jcllib does not exist, cannot run. Run 'zwe init', 'zwe init generate', or submit JCL ${prefix}.SZWESAMP(ZWEGENER) before running this command." "" 999
fi


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
  if [ "${ZWE_CLI_PARAMETER_UPDATE_CONFIG}" = "true" ]; then
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "components.caching-service.storage.vsam.name" "${name}"
    print_level2_message "Zowe configuration is updated successfully."
  fi
fi
print_level2_message "Zowe Caching Service VSAM storage is created successfully."
