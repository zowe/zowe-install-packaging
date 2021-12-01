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

print_level0_message "Configure Zowe Cross Memory Server"

###############################
# constants
proclibs="ZWESISTC ZWESASTC"
size_parmlib='space(15,15) tracks'

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
# read PARMLIB and validate
parmlib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.mvs.parmlib")
if [ -z "${hlq}" -o "${hlq}" = "null" ]; then
  print_error_and_exit "Error ZWEL0157E: PARMLIB (zowe.setup.mvs.parmlib) is not defined in Zowe YAML configuration file." "" 157
fi

# check existence
for mb in ${proclibs}; do
  stc_existence=$(is_data_set_exists "${proclib}(${mb})")
  if [ "${stc_existence}" = "true" ]; then
    if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}" = "true" ]; then
      # warning
      print_message "Warning ZWEL0159W: ${proclib}(${mb}) already exists. This data set member will be overwritten during install."
    else
      # error
      print_error_and_exit "Error ZWEL0158E: ${proclib}(${mb}) already exists. Installation aborts." "" 158
    fi
  fi
done

###############################
# create parmlib if it doesn't exist
parmlib_existence=$(is_data_set_exists "${parmlib}")
if [ "${parmlib_existence}" != "true" ]; then
  print_message "Creating ${parmlib}"
  create_data_set "${parmlib}" "dsntype(library) dsorg(po) recfm(f b) lrecl(80) unit(sysallda) $size_parmlib"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
  fi
fi

###############################
# copy parmlib member ZWESIP00
print_message "Copy ${hlq}.${ZWE_DS_SZWESAMP}(ZWESIP00) to ${parmlib}(ZWESIP00)"
data_set_copy_to_data_set "${hlq}" "${hlq}.${ZWE_DS_SZWESAMP}(ZWESIP00)" "${parmlib}(ZWESIP00)" "-X" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
if [ $? -ne 0 ]; then
  print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
fi

###############################
# put ZWESISTC/ZWESASTC into proclib
# TODO: modify values in STC before copy
for mb in ${proclibs}; do
  print_message "Copy ${hlq}.${ZWE_DS_SZWESAMP}(${mb}) to ${proclib}(${mb})"
  data_set_copy_to_data_set "${hlq}" "${hlq}.${ZWE_DS_SZWESAMP}(${mb})" "${proclib}(${mb})" "-X" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
  fi
done

###############################
# APF authorize loadlib
if [ "${ZWE_CLI_PARAMETER_SKIP_SECURITY_SETUP}" = "true" ]; then
  print_message "Security setup is skipped."
else
  print_message "APF authorize ${hlq}.${ZWE_DS_SZWEAUTH}"
  apf_authorize_data_set "${hlq}.${ZWE_DS_SZWEAUTH}"
  code=$?
  if [ $code -ne 0 ]; then
    exit $code
  else
    print_debug "- APF authorized succeeded."
  fi
fi

###############################
# exit message
print_message
print_level1_message "Zowe Cross Memory Server is configured successfully."
