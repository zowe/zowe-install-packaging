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
  _CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/init/stc/cli.js"
else


print_level1_message "Install Zowe main started task"

###############################
# constants
proclibs="ZWESLSTC ZWESISTC ZWESASTC"

###############################
# validation
require_zowe_yaml

# read prefix and validate
prefix=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.prefix")
if [ -z "${prefix}" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file." "" 157
fi
# read PROCLIB and validate
proclib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.proclib")
if [ -z "${proclib}" ]; then
  print_error_and_exit "Error ZWEL0157E: PROCLIB (zowe.setup.dataset.proclib) is not defined in Zowe YAML configuration file." "" 157
fi
# read JCL library and validate
jcllib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.jcllib")
if [ -z "${jcllib}" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe custom JCL library (zowe.setup.dataset.jcllib) is not defined in Zowe YAML configuration file." "" 157
fi
# read PARMLIB and validate
parmlib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.parmlib")
if [ -z "${parmlib}" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe custom parameter library (zowe.setup.dataset.parmlib) is not defined in Zowe YAML configuration file." "" 157
fi
# read LOADLIB and validate
authLoadlib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.authLoadlib")
if [ -z "${authLoadlib}" ]; then
  # authLoadlib can be empty
  authLoadlib="${prefix}.${ZWE_PRIVATE_DS_SZWEAUTH}"
fi
authPluginLib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.authPluginLib")
if [ -z "${authPluginLib}" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe custom load library (zowe.setup.dataset.authPluginLib) is not defined in Zowe YAML configuration file." "" 157
fi
security_stcs_zowe=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.stcs.zowe")
if [ -z "${security_stcs_zowe}" ]; then
  security_stcs_zowe=${ZWE_PRIVATE_DEFAULT_ZOWE_STC}
fi
security_stcs_zis=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.stcs.zis")
if [ -z "${security_stcs_zis}" ]; then
  security_stcs_zis=${ZWE_PRIVATE_DEFAULT_ZIS_STC}
fi
security_stcs_aux=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.stcs.aux")
if [ -z "${security_stcs_aux}" ]; then
  security_stcs_aux=${ZWE_PRIVATE_DEFAULT_AUX_STC}
fi
target_proclibs="${security_stcs_zowe} ${security_stcs_zis} ${security_stcs_aux}"

# check existence
for mb in ${proclibs}; do
  # source in SZWESAMP
  samp_existence=$(is_data_set_exists "${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(${mb})")
  if [ "${samp_existence}" != "true" ]; then
      print_error_and_exit "Error ZWEL0143E: ${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(${mb}) already exists. This data set member will be overwritten during configuration." "" 143
  fi
done
for mb in ${target_proclibs}; do
  # JCL for preview purpose
  jcl_existence=$(is_data_set_exists "${jcllib}(${mb})")
  if [ "${jcl_existence}" = "true" ]; then
    if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}" = "true" ]; then
      # warning
      print_message "Warning ZWEL0300W: ${jcllib}(${mb}) already exists. This data set member will be overwritten during configuration."
    else
      # print_error_and_exit "Error ZWEL0158E: ${jcllib}(${mb}) already exists." "" 158
      # warning
      print_message "Warning ZWEL0301W: ${jcllib}(${mb}) already exists and will not be overwritten. For upgrades, you must use --allow-overwrite."
    fi
  fi

  # STCs in target proclib
  stc_existence=$(is_data_set_exists "${proclib}(${mb})")
  if [ "${stc_existence}" = "true" ]; then
    if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}" = "true" ]; then
      # warning
      print_message "Warning ZWEL0300W: ${proclib}(${mb}) already exists. This data set member will be overwritten during configuration."
    else
      # print_error_and_exit "Error ZWEL0158E: ${proclib}(${mb}) already exists." "" 158
      # warning
      print_message "Warning ZWEL0301W: ${proclib}(${mb}) already exists and will not be overwritten. For upgrades, you must use --allow-overwrite."
    fi
  fi
done

if [ "${jcl_existence}" = "true" ] &&  [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}" != "true" ]; then
  print_message "Skipped writing to ${jcllib}(${mb}). To write, you must use --allow-overwrite."
else
  ###############################
  # prepare STCs
  # ZWESLSTC
  print_message "Modify ZWESLSTC and save as ${jcllib}(${security_stcs_zowe})"
  tmpfile=$(create_tmp_file $(echo "zwe ${ZWE_CLI_COMMANDS_LIST}" | sed "s# #-#g"))
  print_debug "- Copy ${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(ZWESLSTC) to ${tmpfile}"
  if [[ "$ZWE_CLI_PARAMETER_CONFIG" != /* ]];then
    print_message "CONFIG path defined in ZWESLSTC is converted into absolute path and may contain SYSNAME."
    print_message "Please manually verify if this path works for your environment, especially when you are working in Sysplex environment."
  fi
  result=$(cat "//'${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(ZWESLSTC)'" | \
          sed "s/^\/\/STEPLIB .*\$/\/\/STEPLIB  DD   DSNAME=${authLoadlib},DISP=SHR/" | \
          sed "s#^CONFIG=.*\$#CONFIG=$(convert_to_absolute_path ${ZWE_CLI_PARAMETER_CONFIG})#" \
          > "${tmpfile}")
  code=$?
  chmod 700 "${tmpfile}"
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
    print_error_and_exit "Error ZWEL0159E: Failed to modify ${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(ZWESLSTC)" "" 159
  fi
  print_trace "- ensure ${tmpfile} encoding before copying into data set"
  ensure_file_encoding "${tmpfile}" "SPDX-License-Identifier"
  print_trace "- ${tmpfile} created, copy to ${jcllib}(${security_stcs_zowe})"
  copy_to_data_set "${tmpfile}" "${jcllib}(${security_stcs_zowe})" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}"
  code=$?
  print_trace "- Delete ${tmpfile}"
  rm -f "${tmpfile}"
  if [ ${code} -ne 0 ]; then
    print_error_and_exit "Error ZWEL0160E: Failed to write to ${jcllib}(${security_stcs_zowe}). Please check if target data set is opened by others." "" 160
  fi
  print_debug "- ${jcllib}(${security_stcs_zowe}) is prepared"

  # ZWESISTC
  print_message "Modify ZWESISTC and save as ${jcllib}(${security_stcs_zis})"
  tmpfile=$(create_tmp_file $(echo "zwe ${ZWE_CLI_COMMANDS_LIST}" | sed "s# #-#g"))
  print_debug "- Copy ${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(ZWESISTC) to ${tmpfile}"
  result=$(cat "//'${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(ZWESISTC)'" | \
          sed '/^..STEPLIB/c\
\//STEPLIB  DD   DSNAME='${authLoadlib}',DISP=SHR\
\//         DD   DSNAME='${authPluginLib}',DISP=SHR' | \
          sed "s/^\/\/PARMLIB .*\$/\/\/PARMLIB  DD   DSNAME=${parmlib},DISP=SHR/" \
          > "${tmpfile}")
  code=$?
  chmod 700 "${tmpfile}"
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
    print_error_and_exit "Error ZWEL0159E: Failed to modify ${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(ZWESISTC)" "" 159
  fi
  print_trace "- ensure ${tmpfile} encoding before copying into data set"
  ensure_file_encoding "${tmpfile}" "SPDX-License-Identifier"
  print_trace "- ${tmpfile} created, copy to ${jcllib}(${security_stcs_zis})"
  copy_to_data_set "${tmpfile}" "${jcllib}(${security_stcs_zis})" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}"
  code=$?
  print_trace "- Delete ${tmpfile}"
  rm -f "${tmpfile}"
  if [ ${code} -ne 0 ]; then
    print_error_and_exit "Error ZWEL0160E: Failed to write to ${jcllib}(${security_stcs_zis}). Please check if target data set is opened by others." "" 160
  fi
  print_debug "- ${jcllib}(${security_stcs_zis}) is prepared"

  # ZWESASTC
  print_message "Modify ZWESASTC and save as ${jcllib}(${security_stcs_aux})"
  tmpfile=$(create_tmp_file $(echo "zwe ${ZWE_CLI_COMMANDS_LIST}" | sed "s# #-#g"))
  print_debug "- Copy ${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(ZWESASTC) to ${tmpfile}"
  result=$(cat "//'${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(ZWESASTC)'" | \
          sed '/^..STEPLIB/c\
\//STEPLIB  DD   DSNAME='${authLoadlib}',DISP=SHR\
\//         DD   DSNAME='${authPluginLib}',DISP=SHR' \
          > "${tmpfile}")
  code=$?
  chmod 700 "${tmpfile}"
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
    print_error_and_exit "Error ZWEL0159E: Failed to modify ${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(ZWESASTC)" "" 159
  fi
  print_trace "- ensure ${tmpfile} encoding before copying into data set"
  ensure_file_encoding "${tmpfile}" "SPDX-License-Identifier"
  print_trace "- ${tmpfile} created, copy to ${jcllib}(${security_stcs_aux})"
  copy_to_data_set "${tmpfile}" "${jcllib}(${security_stcs_aux})" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}"
  code=$?
  print_trace "- Delete ${tmpfile}"
  rm -f "${tmpfile}"
  if [ ${code} -ne 0 ]; then
    print_error_and_exit "Error ZWEL0160E: Failed to write to ${jcllib}(${security_stcs_aux}). Please check if target data set is opened by others." "" 160
  fi
  print_debug "- ${jcllib}(${security_stcs_aux}) is prepared"

  print_message
fi

if [ "${stc_existence}" = "true" ] &&  [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}" != "true" ]; then
  print_message "Skipped writing to ${proclib}(${mb}). To write, you must use --allow-overwrite."
else
  ###############################
  # copy to proclib
  for mb in ${target_proclibs}; do
    print_message "Copy ${jcllib}(${mb}) to ${proclib}(${mb})"
    data_set_copy_to_data_set "${prefix}" "${jcllib}(${mb})" "${proclib}(${mb})" "-X" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}"
    if [ $? -ne 0 ]; then
      print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
    fi
  done
fi

###############################
# exit message
print_level2_message "Zowe main started tasks are installed successfully."
fi
