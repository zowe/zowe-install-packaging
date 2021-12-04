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

print_level1_message "Install Zowe main started task"

###############################
# constants
proclibs="ZWESLSTC ZWESISTC ZWESASTC"

###############################
# validation
require_zowe_yaml

# read HLQ and validate
hlq=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.mvs.hlq")
if [ -z "${hlq}" -o "${hlq}" = "null" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe HLQ (zowe.setup.mvs.hlq) is not defined in Zowe YAML configuration file." "" 157
fi
# read PROCLIB and validate
proclib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.mvs.proclib")
if [ -z "${hlq}" -o "${hlq}" = "null" ]; then
  print_error_and_exit "Error ZWEL0157E: PROCLIB (zowe.setup.mvs.proclib) is not defined in Zowe YAML configuration file." "" 157
fi

# check existence
for mb in ${proclibs}; do
  stc_existence=$(is_data_set_exists "${proclib}(${mb})")
  if [ "${stc_existence}" = "true" ]; then
    if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}" = "true" ]; then
      # warning
      print_message "Warning ZWEL0158W: ${proclib}(${mb}) already exists. This data set member will be overwritten during install."
    else
      # error
      print_error_and_exit "Error ZWEL0158E: ${proclib}(${mb}) already exists. Installation aborts." "" 158
    fi
  fi
done

###############################
# put into proclib
# TODO: modify values in STC before copy
for mb in ${proclibs}; do
  print_message "Copy ${hlq}.${ZWE_DS_SZWESAMP}(${mb}) to ${proclib}(${mb})"
  data_set_copy_to_data_set "${hlq}" "${hlq}.${ZWE_DS_SZWESAMP}(${mb})" "${proclib}(${mb})" "-X" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
  fi
done

###############################
# exit message
print_level2_message "Zowe main started tasks are installed successfully."
