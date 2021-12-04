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
if [ -z "${proclib}" -o "${proclib}" = "null" ]; then
  print_error_and_exit "Error ZWEL0157E: PROCLIB (zowe.setup.mvs.proclib) is not defined in Zowe YAML configuration file." "" 157
fi
# read JCL library and validate
jcllib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.mvs.jcllib")
if [ -z "${jcllib}" -o "${jcllib}" = "null" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe custom JCL library (zowe.setup.mvs.jcllib) is not defined in Zowe YAML configuration file." "" 157
fi
# read PARMLIB and validate
parmlib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.mvs.parmlib")
if [ -z "${parmlib}" -o "${parmlib}" = "null" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe custom parameter library (zowe.setup.mvs.parmlib) is not defined in Zowe YAML configuration file." "" 157
fi
# read LOADLIB and validate
authLoadlib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.mvs.authLoadlib")
if [ -z "${authLoadlib}" -o "${authLoadlib}" = "null" ]; then
  # authLoadlib can be empty
  authLoadlib="${hlq}.${ZWE_DS_SZWEAUTH}"
fi
security_stcs_zowe=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.stcs.zowe")
if [ -z "${security_stcs_zowe}" -o "${security_stcs_zowe}" = "null" ]; then
  security_stcs_zowe=${ZWE_DEFAULT_ZOWE_STC}
fi
security_stcs_xmem=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.stcs.xmem")
if [ -z "${security_stcs_xmem}" -o "${security_stcs_xmem}" = "null" ]; then
  security_stcs_xmem=${ZWE_DEFAULT_XMEM_STC}
fi
security_stcs_aux=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.stcs.aux")
if [ -z "${security_stcs_aux}" -o "${security_stcs_aux}" = "null" ]; then
  security_stcs_aux=${ZWE_DEFAULT_AUX_STC}
fi
target_proclibs="${security_stcs_zowe} ${security_stcs_xmem} ${security_stcs_aux}"

# check existence
for mb in ${proclibs}; do
  jcl_existence=$(is_data_set_exists "${jcllib}(${mb})")
  if [ "${jcl_existence}" = "true" ]; then
    if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}" = "true" ]; then
      # warning
      print_message "Warning ZWEL0158W: ${jcllib}(${mb}) already exists. This data set member will be overwritten during configuration."
    else
      # error
      print_error_and_exit "Error ZWEL0158E: ${jcllib}(${mb}) already exists." "" 158
    fi
  fi

  stc_existence=$(is_data_set_exists "${proclib}(${mb})")
  if [ "${stc_existence}" = "true" ]; then
    if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}" = "true" ]; then
      # warning
      print_message "Warning ZWEL0158W: ${proclib}(${mb}) already exists. This data set member will be overwritten during configuration."
    else
      # error
      print_error_and_exit "Error ZWEL0158E: ${proclib}(${mb}) already exists." "" 158
    fi
  fi
done

###############################
# prepare STCs
# ZWESLSTC
print_message "Modify ZWESLSTC"
tmpfile=$(create_tmp_file $(echo "zwe ${ZWE_CLI_COMMANDS_LIST}" | sed "s# #-#g"))
print_debug "- Copy ${hlq}.${ZWE_DS_SZWESAMP}(ZWESLSTC) to ${tmpfile}"
result=$(cat "//'${hlq}.${ZWE_DS_SZWESAMP}(ZWESLSTC)'" | sed "s#^INSTANCE_DIR=.*\$#INSTANCE_DIR=${ZWE_CLI_PARAMETER_CONFIG}#" > "${tmpfile}")
code=$?
if [ ${code} -eq 0 ]; then
  print_debug "  * Succeeded"
  print_trace "  * Exit code: ${code}"
  print_trace "  * Output:"
  if [ -n "${result}" ]; then
    print_trace "$(padding_left "${result}" "    ")"
  fi
else
  print_debug "  * Failed"
  print_error "  * Exit code: ${code}"
  print_error "  * Output:"
  if [ -n "${result}" ]; then
    print_error "$(padding_left "${result}" "    ")"
  fi
fi
if [ ! -f "${tmpfile}" ]; then
  print_error_and_exit "Error ZWEL0159E: Failed to modify ${hlq}.${ZWE_DS_SZWESAMP}(ZWESLSTC)" "" 159
fi
print_trace "- ${tmpfile} created, copy to ${jcllib}(${security_stcs_zowe})"
copy_to_data_set "${tmpfile}" "${jcllib}(${security_stcs_zowe})" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
code=$?
print_trace "- Delete ${tmpfile}"
rm -f "${tmpfile}"
if [ ${code} -ne 0 ]; then
  print_error_and_exit "Error ZWEL0160E: Failed to write to ${jcllib}(${security_stcs_zowe}). Please check if target data set is opened by others." "" 160
fi
print_debug "- ${jcllib}(${security_stcs_zowe}) is prepared"

# ZWESISTC
print_message "Modify ZWESISTC"
tmpfile=$(create_tmp_file $(echo "zwe ${ZWE_CLI_COMMANDS_LIST}" | sed "s# #-#g"))
print_debug "- Copy ${hlq}.${ZWE_DS_SZWESAMP}(ZWESISTC) to ${tmpfile}"
result=$(cat "//'${hlq}.${ZWE_DS_SZWESAMP}(ZWESISTC)'" | \
        sed "s/^\/\/STEPLIB .*\$/\/\/STEPLIB  DD   DSNAME=${authLoadlib},DISP=SHR/" | \
        sed "s/^\/\/PARMLIB .*\$/\/\/PARMLIB  DD   DSNAME=${parmlib},DISP=SHR/" \
        > "${tmpfile}")
code=$?
if [ ${code} -eq 0 ]; then
  print_debug "  * Succeeded"
  print_trace "  * Exit code: ${code}"
  print_trace "  * Output:"
  if [ -n "${result}" ]; then
    print_trace "$(padding_left "${result}" "    ")"
  fi
else
  print_debug "  * Failed"
  print_error "  * Exit code: ${code}"
  print_error "  * Output:"
  if [ -n "${result}" ]; then
    print_error "$(padding_left "${result}" "    ")"
  fi
  exit 1
fi
if [ ! -f "${tmpfile}" ]; then
  print_error_and_exit "Error ZWEL0159E: Failed to modify ${hlq}.${ZWE_DS_SZWESAMP}(ZWESISTC)" "" 159
fi
print_trace "- ${tmpfile} created, copy to ${jcllib}(${security_stcs_xmem})"
copy_to_data_set "${tmpfile}" "${jcllib}(${security_stcs_xmem})" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
code=$?
print_trace "- Delete ${tmpfile}"
rm -f "${tmpfile}"
if [ ${code} -ne 0 ]; then
  print_error_and_exit "Error ZWEL0160E: Failed to write to ${jcllib}(${security_stcs_xmem}). Please check if target data set is opened by others." "" 160
fi
print_debug "- ${jcllib}(${security_stcs_xmem}) is prepared"

# ZWESASTC
print_message "Modify ZWESASTC"
tmpfile=$(create_tmp_file $(echo "zwe ${ZWE_CLI_COMMANDS_LIST}" | sed "s# #-#g"))
print_debug "- Copy ${hlq}.${ZWE_DS_SZWESAMP}(ZWESASTC) to ${tmpfile}"
result=$(cat "//'${hlq}.${ZWE_DS_SZWESAMP}(ZWESASTC)'" | \
        sed "s/^\/\/STEPLIB .*\$/\/\/STEPLIB  DD   DSNAME=${authLoadlib},DISP=SHR/" \
        > "${tmpfile}")
code=$?
if [ ${code} -eq 0 ]; then
  print_debug "  * Succeeded"
  print_trace "  * Exit code: ${code}"
  print_trace "  * Output:"
  if [ -n "${result}" ]; then
    print_trace "$(padding_left "${result}" "    ")"
  fi
else
  print_debug "  * Failed"
  print_error "  * Exit code: ${code}"
  print_error "  * Output:"
  if [ -n "${result}" ]; then
    print_error "$(padding_left "${result}" "    ")"
  fi
  exit 1
fi
if [ ! -f "${tmpfile}" ]; then
  print_error_and_exit "Error ZWEL0159E: Failed to modify ${hlq}.${ZWE_DS_SZWESAMP}(ZWESASTC)" "" 159
fi
print_trace "- ${tmpfile} created, copy to ${jcllib}(${security_stcs_aux})"
copy_to_data_set "${tmpfile}" "${jcllib}(${security_stcs_aux})" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
code=$?
print_trace "- Delete ${tmpfile}"
rm -f "${tmpfile}"
if [ ${code} -ne 0 ]; then
  print_error_and_exit "Error ZWEL0160E: Failed to write to ${jcllib}(${security_stcs_aux}). Please check if target data set is opened by others." "" 160
fi
print_debug "- ${jcllib}(${security_stcs_aux}) is prepared"

print_message

###############################
# copy to proclib
for mb in ${target_proclibs}; do
  print_message "Copy ${jcllib}(${mb}) to ${proclib}(${mb})"
  data_set_copy_to_data_set "${hlq}" "${jcllib}(${mb})" "${proclib}(${mb})" "-X" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
  fi
done

###############################
# exit message
print_level2_message "Zowe main started tasks are installed successfully."
