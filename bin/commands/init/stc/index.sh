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

print_level0_message "Install Zowe started tasks"

###############################
# constants
sizeAUTH='space(30,15) tracks'
sizeSAMP='space(15,15) tracks'

###############################
# validation
require_zowe_yaml

# read HLQ and validate
hlq=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.mvs.hlq")
if [ -z "${hlq}" -o "${hlq}" = "null" ]; then
  print_error_and_exit "Error ZWES0157E: Zowe HLQ (zowe.setup.mvs.hlq) is not defined in Zowe YAML configuration file." "" 157
fi
# read PROCLIB and validate
proclib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.mvs.proclib")
if [ -z "${hlq}" -o "${hlq}" = "null" ]; then
  print_error_and_exit "Error ZWES0157E: PROCLIB (zowe.setup.mvs.proclib) is not defined in Zowe YAML configuration file." "" 157
fi

# check existence
slstc_existence=$(is_data_set_exists "${proclib}(ZWESLSTC)")
sistc_existence=$(is_data_set_exists "${proclib}(ZWESISTC)")
sastc_existence=$(is_data_set_exists "${proclib}(ZWESASTC)")
if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}" = "true" ]; then
  # warning
  if [ "${slstc_existence}" = "true" ]; then
    print_message "Warning ZWES0159W: ${proclib}(ZWESLSTC) already exists. This data set member will be overwritten during install."
  fi
  if [ "${sistc_existence}" = "true" ]; then
    print_message "Warning ZWES0159W: ${proclib}(ZWESISTC) already exists. This data set member will be overwritten during install."
  fi
  if [ "${sastc_existence}" = "true" ]; then
    print_message "Warning ZWES0159W: ${proclib}(ZWESASTC) already exists. This data set member will be overwritten during install."
  fi
else
  # error
  if [ "${slstc_existence}" = "true" ]; then
    print_error_and_exit "Error ZWES0158E: ${proclib}(ZWESLSTC) already exists. Installation aborts." "" 158
  fi
  if [ "${sistc_existence}" = "true" ]; then
    print_error_and_exit "Error ZWES0158E: ${proclib}(ZWESISTC) already exists. Installation aborts." "" 158
  fi
  if [ "${sastc_existence}" = "true" ]; then
    print_error_and_exit "Error ZWES0158E: ${proclib}(ZWESASTC) already exists. Installation aborts." "" 158
  fi
fi

# TODO: modify values in STC before copy

###############################
# copy data sets
print_message "Copy ${hlq}.${ZWE_DS_SZWESAMP}(ZWESLSTC) to ${proclib}(ZWESLSTC)"
data_set_copy_to_data_set "${hlq}" "${hlq}.${ZWE_DS_SZWESAMP}(ZWESLSTC)" "${proclib}(ZWESLSTC)" "-X" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
if [ $? -ne 0 ]; then
  print_error_and_exit "Error ZWES0111E: Command aborts with error." "" 111
fi
print_message "Copy ${hlq}.${ZWE_DS_SZWESAMP}(ZWESISTC) to ${proclib}(ZWESISTC)"
data_set_copy_to_data_set "${hlq}" "${hlq}.${ZWE_DS_SZWESAMP}(ZWESISTC)" "${proclib}(ZWESISTC)" "-X" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
if [ $? -ne 0 ]; then
  print_error_and_exit "Error ZWES0111E: Command aborts with error." "" 111
fi
print_message "Copy ${hlq}.${ZWE_DS_SZWESAMP}(ZWESASTC) to ${proclib}(ZWESASTC)"
data_set_copy_to_data_set "${hlq}" "${hlq}.${ZWE_DS_SZWESAMP}(ZWESASTC)" "${proclib}(ZWESASTC)" "-X" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
if [ $? -ne 0 ]; then
  print_error_and_exit "Error ZWES0111E: Command aborts with error." "" 111
fi

###############################
# exit message
print_message
print_level1_message "Zowe MVS data sets are installed successfully."
