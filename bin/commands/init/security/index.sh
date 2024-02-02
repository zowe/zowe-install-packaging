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

print_level1_message "Run Zowe security configurations"

###############################
# validation
require_zowe_yaml

# read prefix and validate
prefix=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.prefix")
if [ -z "${prefix}" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file." "" 157
fi
security_product=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.product")
if [ -z "${security_product}" ]; then
  print_error_and_exit "Error ZWEL0157E: (zowe.setup.security.product) is not defined in Zowe YAML configuration file." "" 157
fi

# read JCL library and validate
jcllib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.jcllib")
does_jcl_exist=$(is_data_set_exists "${jcllib}(ZWEI${security_product})")
if [ "${does_jcl_exist}" = "false" ]; then
  zwecli_inline_execute_command init generate
fi
does_jcl_exist=$(is_data_set_exists "${jcllib}(ZWEI${security_product})")
if [ "${does_jcl_exist}" = "false" ]; then
  print_error_and_exit "Error ZWEL0999E: ${jcllib}(ZWEI${security_product}) does not exist, cannot run. Run 'zwe init', 'zwe init generate', or submit JCL ${prefix}.SZWESAMP(ZWEGENER) before running this command." "" 999
fi



security_groups_admin=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.groups.admin")
if [ -z "${security_groups_admin}" ]; then
  print_error_and_exit "Error ZWEL0157E: (zowe.setup.security.groups.admin) is not defined in Zowe YAML configuration file." "" 157
fi
security_groups_stc=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.groups.stc")
if [ -z "${security_groups_stc}" ]; then
  print_error_and_exit "Error ZWEL0157E: (zowe.setup.security.groups.stc) is not defined in Zowe YAML configuration file." "" 157
fi
security_groups_sysProg=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.groups.sysProg")
if [ -z "${security_groups_sysProg}" ]; then
  print_error_and_exit "Error ZWEL0157E: (zowe.setup.security.groups.sysProg) is not defined in Zowe YAML configuration file." "" 157
fi
security_users_zowe=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.users.zowe")
if [ -z "${security_users_zowe}" ]; then
  print_error_and_exit "Error ZWEL0157E: (zowe.setup.security.users.zowe) is not defined in Zowe YAML configuration file." "" 157
fi
security_users_zis=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.users.zis")
if [ -z "${security_users_zis}" ]; then
  print_error_and_exit "Error ZWEL0157E: (zowe.setup.security.users.zis) is not defined in Zowe YAML configuration file." "" 157
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


jcl_file=$(create_tmp_file)
copy_mvs_to_uss "${jcllib}(ZWEI${security_product})" "${jcl_file}"
jcl_contents=$(cat "${jcl_file}")

print_message "Template JCL: ${prefix}.SZWESAMP(ZWEI${security_product}) , Executable JCL: ${jcllib}(ZWEI${security_product})"
print_message "--- JCL Content ---"
print_message "$jcl_contents"
print_message "--- End of JCL ---"

job_has_failures=
if [ "${ZWE_CLI_PARAMETER_SECURITY_DRY_RUN}" = "true" ]; then
  print_message "JCL not submitted, command run with dry run flag."
  print_message "To perform command, re-run command without dry run flag, or submit the JCL directly"
  rm $jcl_file
else
  ###############################
  # submit job
  print_message "Submitting Job ZWEI${security_product}"
  jobid=$(submit_job "//'${jcllib}(ZWEI${security_product})'")
  code=$?
  if [ ${code} -ne 0 ]; then
    job_has_failures=true
    if [ "${ZWE_CLI_PARAMETER_IGNORE_SECURITY_FAILURES}" = "true" ]; then
      print_error "Warning ZWEL0161W: Failed to run JCL ${jcllib}(ZWEI${security_product})."
      # skip wait for job status step
      jobid=
    else
      print_error_and_exit "Error ZWEL0161E: Failed to run JCL ${jcllib}(ZWEI${security_product})." "" 161
    fi
  fi

  if [ -n "${jobid}" ]; then
    print_debug "- job id ${jobid}"
    jobstate=$(wait_for_job "${jobid}")
    code=$?
    if [ ${code} -eq 1 ]; then
      job_has_failures=true
      if [ "${ZWE_CLI_PARAMETER_IGNORE_SECURITY_FAILURES}" = "true" ]; then
        print_error "Warning ZWEL0162W: Failed to find job ${jobid} result."
      else
        print_error_and_exit "Error ZWEL0162E: Failed to find job ${jobid} result." "" 162
      fi
    fi
    jobname=$(echo "${jobstate}" | awk -F, '{print $2}')
    jobcctext=$(echo "${jobstate}" | awk -F, '{print $3}')
    jobcccode=$(echo "${jobstate}" | awk -F, '{print $4}')
    if [ ${code} -eq 0 ]; then
      print_message "- Job ${jobname}(${jobid}) ends with code ${jobcccode} (${jobcctext})."

      print_message ""
      print_message "WARNING: Due to the limitation of the ZWESECUR job, exit with 0 does not mean"
      print_message "         the job is fully successful. Please check the job log to determine"
      print_message "         if there are any inline errors."
      print_message ""
    else
      job_has_failures=true
      if [ "${ZWE_CLI_PARAMETER_IGNORE_SECURITY_FAILURES}" = "true" ]; then
        print_error "Warning ZWEL0163W: Job ${jobname}(${jobid}) ends with code ${jobcccode} (${jobcctext})."
      else
        print_error_and_exit "Error ZWEL0163E: Job ${jobname}(${jobid}) ends with code ${jobcccode} (${jobcctext})." "" 163
      fi
    fi
  fi
fi

###############################
# exit message
if [ "${job_has_failures}" = "true" ]; then
  print_level2_message "Failed to apply Zowe security configurations. Please check job log for details."
else
  print_level2_message "Command run successfully."
fi
