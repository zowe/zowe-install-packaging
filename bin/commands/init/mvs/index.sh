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
cust_ds_list="parmlib|Zowe parameter library|dsntype(library) dsorg(po) recfm(f b) lrecl(80) unit(sysallda) space(15,15) tracks
jcllib|Zowe JCL library|dsntype(library) dsorg(po) recfm(f b) lrecl(80) unit(sysallda) space(15,15) tracks
authLoadlib|Zowe authorized load library|dsntype(library) dsorg(po) recfm(u) lrecl(0) blksize(32760) unit(sysallda) space(30,15) tracks
authPluginLib|Zowe authorized plugin library|dsntype(library) dsorg(po) recfm(u) lrecl(0) blksize(32760) unit(sysallda) space(30,15) tracks"

###############################
# validation
require_zowe_yaml

# read HLQ and validate
hlq=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.mvs.hlq")
if [ -z "${hlq}" -o "${hlq}" = "null" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe high level qualifier (zowe.setup.mvs.hlq) is not defined in Zowe YAML configuration file." "" 157
fi

###############################
# create data sets if they are not exist
print_message "Create data sets if they are not exist"
while read -r line; do
  key=$(echo "${line}" | awk -F"|" '{print $1}')
  name=$(echo "${line}" | awk -F"|" '{print $2}')
  spec=$(echo "${line}" | awk -F"|" '{print $3}')
  
  # read def and validate
  ds=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.mvs.${key}")
  if [ -z "${ds}" -o "${ds}" = "null" ]; then
    # authLoadlib can be empty
    if [ "${key}" = "authLoadlib" ]; then
      continue
    else
      print_error_and_exit "Error ZWEL0157E: ${name} (zowe.setup.mvs.${key}) is not defined in Zowe YAML configuration file." "" 157
    fi
  fi
  # check existence
  ds_existence=$(is_data_set_exists "${ds}")
  if [ "${ds_existence}" = "true" ]; then
    if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}" = "true" ]; then
      # warning
      print_message "Warning ZWEL0300W: ${ds} already exists. Members in this data set will be overwritten."
    else
      # error
      print_error_and_exit "Error ZWEL0158E: ${ds} already exists." "" 158
    fi
  else
    print_message "Creating ${ds}"
    create_data_set "${ds}" "${spec}"
    if [ $? -ne 0 ]; then
      print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
    fi
  fi
done <<EOF
$(echo "${cust_ds_list}")
EOF
print_message

###############################
# copy sample lib members
parmlib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.mvs.parmlib")
for ds in ZWESIP00; do
  print_message "Copy ${hlq}.${ZWE_PRIVATE_DS_SZWESAMP}(${ds}) to ${parmlib}(${ds})"
  data_set_copy_to_data_set "${hlq}" "${hlq}.${ZWE_PRIVATE_DS_SZWESAMP}(${ds})" "${parmlib}(${ds})" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
  fi
done

###############################
# copy auth lib members
# FIXME: data_set_copy_to_data_set cannot be used to copy program?
authLoadlib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.mvs.authLoadlib")
if [ -n "${authLoadlib}" -a "${authLoadlib}" != "null" ]; then
  for ds in ZWESIS01 ZWESAUX; do
    print_message "Copy components/zss/LOADLIB/${ds} to ${authLoadlib}(${ds})"
    # data_set_copy_to_data_set "${hlq}" "${hlq}.${ZWE_PRIVATE_DS_SZWEAUTH}(${ds})" "${authLoadlib}(${ds})" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
    copy_to_data_set "${ZWE_zowe_runtimeDirectory}/components/zss/LOADLIB/${ds}" "${authLoadlib}(${ds})" "-X" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
    if [ $? -ne 0 ]; then
      print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
    fi
  done
  for ds in ZWELNCH; do
    print_message "Copy components/launcher/bin/zowe_launcher to ${authLoadlib}(${ds})"
    # data_set_copy_to_data_set "${hlq}" "${hlq}.${ZWE_PRIVATE_DS_SZWEAUTH}(${ds})" "${authLoadlib}(${ds})" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
    copy_to_data_set "${ZWE_zowe_runtimeDirectory}/components/launcher/bin/zowe_launcher" "${authLoadlib}(${ds})" "-X" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
    if [ $? -ne 0 ]; then
      print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
    fi
  done
fi

###############################
# exit message
print_level2_message "Zowe custom data sets are initialized successfully."
