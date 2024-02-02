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
does_jcl_exist=$(is_data_set_exists "${jcllib}(ZWEISTC)")
if [ "${does_jcl_exist}" = "false" ]; then
  zwecli_inline_execute_command init generate
fi
does_jcl_exist=$(is_data_set_exists "${jcllib}(ZWEISTC)")
if [ "${does_jcl_exist}" = "false" ]; then
  print_error_and_exit "Error ZWEL0999E: ${jcllib}(ZWEISTC) does not exist, cannot run. Run 'zwe init', 'zwe init generate', or submit JCL ${prefix}.SZWESAMP(ZWEGENER) before running this command." "" 999
fi

security_stcs_zowe=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.stcs.zowe")
if [ -z "${security_stcs_zowe}" ]; then
  print_error_and_exit "Error ZWEL0157E: (zowe.setup.security.stcs.zowe) is not defined in Zowe YAML configuration file." "" 157
fi
security_stcs_zis=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.stcs.zis")
if [ -z "${security_stcs_zis}" ]; then
  print_error_and_exit "Error ZWEL0157E: (zowe.setup.security.stcs.zis) is not defined in Zowe YAML configuration file." "" 157
fi
security_stcs_aux=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.stcs.aux")
if [ -z "${security_stcs_aux}" ]; then
  print_error_and_exit "Error ZWEL0157E: (zowe.setup.security.stcs.aux) is not defined in Zowe YAML configuration file." "" 157
fi
target_proclibs="${security_stcs_zowe} ${security_stcs_zis} ${security_stcs_aux}"

for mb in ${target_proclibs}; do
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

if [ "${stc_existence}" = "true" ] &&  [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}" != "true" ]; then
  print_message "Skipped writing to ${proclib}. To write, you must use --allow-overwrite."
else

  jcl_file=$(create_tmp_file)
  copy_mvs_to_uss "${jcllib}(ZWEISTC)" "${jcl_file}"
  jcl_contents=$(cat "${jcl_file}")

  print_message "Template JCL: ${prefix}.SZWESAMP(ZWEISTC) , Executable JCL: ${jcllib}(ZWEISTC)"
  print_message "--- JCL Content ---"
  print_message "$jcl_contents"
  print_message "--- End of JCL ---"

  if [ -z "${ZWE_CLI_PARAMETER_DRY_RUN}" ]; then
    print_message "Submitting Job ZWEISTC"
    jobid=$(submit_job $jcl_file)
    code=$?
    if [ ${code} -ne 0 ]; then
      print_error_and_exit "Error ZWEL0161E: Failed to run JCL ${jcllib}(ZWEISTC)." "" 161
    fi
    print_debug "- job id ${jobid}"

    jobstate=$(wait_for_job "${jobid}")
    code=$?
    rm $jcl_file
    if [ ${code} -eq 1 ]; then
      print_error_and_exit "Error ZWEL0162E: Failed to find job ${jobid} result." "" 162
    fi
    jobname=$(echo "${jobstate}" | awk -F, '{print $2}')
    jobcctext=$(echo "${jobstate}" | awk -F, '{print $3}')
    jobcccode=$(echo "${jobstate}" | awk -F, '{print $4}')

    if [ "${code}" -eq 0 ]; then
      print_level2_message "Zowe main started tasks are installed successfully."
    else
      print_error_and_exit "Error ZWEL0163E: Job ${jobname}(${jobid}) ends with code ${jobcccode} (${jobcctext})." "" 163
    fi
  else
    print_message "JCL not submitted, command run with dry run flag."
    print_message "To perform command, re-run command without dry run flag, or submit the JCL directly"
    print_level2_message "Command run successfully."
    rm $jcl_file
  fi
fi


