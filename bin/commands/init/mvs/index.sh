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
  _CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/init/mvs/cli.js"
else
  print_error_and_exit "Error ZWEL0316E: Command requires zowe.useConfigmgr=true to use." "" 316
fi


print_level1_message "Initialize Zowe custom data sets"

###############################
# constants
cust_ds_list="parmlib|Zowe parameter library
authLoadlib|Zowe authorized load library
authPluginLib|Zowe authorized plugin library"

###############################
# validation
require_zowe_yaml

# read prefix and validate
prefix=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.prefix")
if [ -z "${prefix}" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file." "" 157
fi

jcllib=$(verify_generated_jcl)
if [ "$?" -eq 1 ]; then
  print_error_and_exit "Error ZWEL0999E: zowe.setup.dataset.jcllib does not exist, cannot run. Run 'zwe init', 'zwe init generate', or submit JCL ${prefix}.SZWESAMP(ZWEGENER) before running this command." "" 999
fi

###############################
# create data sets if they do not exist
print_message "Create data sets if they do not exist"
while read -r line; do
  key=$(echo "${line}" | awk -F"|" '{print $1}')
  name=$(echo "${line}" | awk -F"|" '{print $2}')
  
  # read def and validate
  ds=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.${key}")
  if [ -z "${ds}" ]; then
    # authLoadlib can be empty
    if [ "${key}" = "authLoadlib" ]; then
      continue
    else
      print_error_and_exit "Error ZWEL0157E: ${name} (zowe.setup.dataset.${key}) is not defined in Zowe YAML configuration file." "" 157
    fi
  fi

  if [ "${key}" = "authLoadlib" ]; then
    if [ "${ds}" = "${prefix}.SZWEAUTH" ]; then
      run_aloadlib_create="false"
    else
      run_aloadlib_create="true"
      # check existence
      ds_existence=$(is_data_set_exists "${ds}")
      if [ "${ds_existence}" = "true" ]; then
        if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}" = "true" ]; then
          print_message "Warning ZWEL0300W: ${ds} already exists. Members in this data set will be overwritten."
        else
          print_message "Warning ZWEL0301W: ${ds} already exists and will not be overwritten. For upgrades, you must use --allow-overwrite."
        fi
      fi       
    fi
  else
    # check existence
    ds_existence=$(is_data_set_exists "${ds}")
    if [ "${ds_existence}" = "true" ]; then
      if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}" = "true" ]; then
        print_message "Warning ZWEL0300W: ${ds} already exists. Members in this data set will be overwritten."
      else
        print_message "Warning ZWEL0301W: ${ds} already exists and will not be overwritten. For upgrades, you must use --allow-overwrite."
      fi
    fi
  fi
done <<EOF
$(echo "${cust_ds_list}")
EOF

print_message

if [ "${ds_existence}" = "true" ] &&  [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}" != "true" ]; then
  print_message "Skipped writing to ${ds}. To write, you must use --allow-overwrite."
  print_level2_message "Zowe custom data sets initialized with errors."
else


  print_and_handle_jcl "//'${jcllib}(ZWEIMVS)'" "ZWEIMVS" "${jcllib}" "${prefix}"
  if [ "${run_aloadlib_create}" = "true" ]; then
    print_and_handle_jcl "//'${jcllib}(ZWEIMVS2)'" "ZWEIMVS2" "${jcllib}" "${prefix}"
  fi

  print_level2_message "Zowe custom data sets are initialized successfully."
fi


