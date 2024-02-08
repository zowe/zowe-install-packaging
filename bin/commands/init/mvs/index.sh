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

print_level1_message "Initialize Zowe custom data sets"

###############################
# constants
cust_ds_list="parmlib|Zowe parameter library
jcllib|Zowe JCL library
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

jcllib_location=$(verify_generated_jcl)

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
  elif [ "${key}" = "authLoadlib" ]; then
    if [ "${ds}" = "${prefix}.SZWESAMP" ]; then
      run_aloadlib_create="false"
    else
      run_aloadlib_create="true"
    fi
  fi
  # check existence
  ds_existence=$(is_data_set_exists "${ds}")
  if [ "${ds_existence}" = "true" ]; then
    if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}" = "true" ]; then
      # warning
      print_message "Warning ZWEL0300W: ${ds} already exists. Members in this data set will be overwritten."
    else
      # print_error_and_exit "Error ZWEL0158E: ${ds} already exists." "" 158
      # warning
      print_message "Warning ZWEL0301W: ${ds} already exists and will not be overwritten. For upgrades, you must use --allow-overwrite."
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


  print_and_handle_jcl "//'${jcllib_location}(ZWEIMVS)'" "ZWEIMVS" "${jcllib_location}" "${prefix}"
  if [ "${run_aloadlib_create}" = "true" ]; then
    print_and_handle_jcl "//'${jcllib_location}(ZWEIMVS2)'" "ZWEIMVS2" "${jcllib_location}" "${prefix}"
  fi

  print_level2_message "Zowe custom data sets are initialized successfully."
fi


