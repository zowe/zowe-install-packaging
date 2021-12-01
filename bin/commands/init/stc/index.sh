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

print_level0_message "Install Zowe main started task"

###############################
# constants

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
if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}" = "true" ]; then
  # warning
  if [ "${slstc_existence}" = "true" ]; then
    print_message "Warning ZWES0159W: ${proclib}(ZWESLSTC) already exists. This data set member will be overwritten during install."
  fi
else
  # error
  if [ "${slstc_existence}" = "true" ]; then
    print_error_and_exit "Error ZWES0158E: ${proclib}(ZWESLSTC) already exists. Installation aborts." "" 158
  fi
fi

# TODO: modify values in STC before copy

###############################
# put ZWESLSTC into proclib
print_message "Copy ${hlq}.${ZWE_DS_SZWESAMP}(ZWESLSTC) to ${proclib}(ZWESLSTC)"
data_set_copy_to_data_set "${hlq}" "${hlq}.${ZWE_DS_SZWESAMP}(ZWESLSTC)" "${proclib}(ZWESLSTC)" "-X" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
if [ $? -ne 0 ]; then
  print_error_and_exit "Error ZWES0111E: Command aborts with error." "" 111
fi

###############################
# exit message
print_message
print_level1_message "Zowe main started task is installed successfully."
