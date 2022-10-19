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
  _CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/init/cli.js"
else


print_level1_message "Run Zowe security configurations"

###############################
# constants

###############################
# validation
require_zowe_yaml

# read prefix and validate
prefix=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.prefix")
if [ -z "${prefix}" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file." "" 157
fi
# read JCL library and validate
jcllib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.jcllib")
if [ -z "${jcllib}" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe custom JCL library (zowe.setup.dataset.jcllib) is not defined in Zowe YAML configuration file." "" 157
fi
security_product=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.product")
if [ -z "${security_product}" ]; then
  security_product=RACF
fi
security_groups_admin=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.groups.admin")
if [ -z "${security_groups_admin}" ]; then
  security_groups_admin=${ZWE_PRIVATE_DEFAULT_ADMIN_GROUP}
fi
security_groups_stc=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.groups.stc")
if [ -z "${security_groups_stc}" ]; then
  security_groups_stc=${ZWE_PRIVATE_DEFAULT_ADMIN_GROUP}
fi
security_groups_sysProg=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.groups.sysProg")
if [ -z "${security_groups_sysProg}" ]; then
  security_groups_sysProg=${ZWE_PRIVATE_DEFAULT_ADMIN_GROUP}
fi
security_users_zowe=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.users.zowe")
if [ -z "${security_users_zowe}" ]; then
  security_users_zowe=${ZWE_PRIVATE_DEFAULT_ZOWE_USER}
fi
security_users_zis=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.users.zis")
if [ -z "${security_users_zis}" ]; then
  security_users_zis=${ZWE_PRIVATE_DEFAULT_ZIS_USER}
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

###############################
# prepare ZWESECUR JCL
print_message "Modify ZWESECUR"
tmpfile=$(create_tmp_file $(echo "zwe ${ZWE_CLI_COMMANDS_LIST}" | sed "s# #-#g"))
tmpdsm=$(create_data_set_tmp_member "${jcllib}" "ZW$(date +%H%M)")
print_debug "- Copy ${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(ZWESECUR) to ${tmpfile}"
# cat "//'IBMUSER.ZWEV2.SZWESAMP(ZWESECUR)'" | sed "s/^\\/\\/ \\+SET \\+PRODUCT=.*\\$/\\/\\         SET  PRODUCT=ACF2         * RACF, ACF2, or TSS/"
result=$(cat "//'${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(ZWESECUR)'" | \
        sed  "s/^\/\/ \+SET \+PRODUCT=.*\$/\/\/         SET  PRODUCT=${security_product}/" | \
        sed "s/^\/\/ \+SET \+ADMINGRP=.*\$/\/\/         SET  ADMINGRP=${security_groups_admin}/" | \
        sed   "s/^\/\/ \+SET \+STCGRP=.*\$/\/\/         SET  STCGRP=${security_groups_stc}/" | \
        sed "s/^\/\/ \+SET \+ZOWEUSER=.*\$/\/\/         SET  ZOWEUSER=${security_users_zowe}/" | \
        sed  "s/^\/\/ \+SET \+ZISUSER=.*\$/\/\/         SET  ZISUSER=${security_users_zis}/" | \
        sed  "s/^\/\/ \+SET \+ZOWESTC=.*\$/\/\/         SET  ZOWESTC=${security_stcs_zowe}/" | \
        sed   "s/^\/\/ \+SET \+ZISSTC=.*\$/\/\/         SET  ZISSTC=${security_stcs_zis}/" | \
        sed   "s/^\/\/ \+SET \+AUXSTC=.*\$/\/\/         SET  AUXSTC=${security_stcs_aux}/" | \
        sed      "s/^\/\/ \+SET \+HLQ=.*\$/\/\/         SET  HLQ=${prefix}/" | \
        sed  "s/^\/\/ \+SET \+SYSPROG=.*\$/\/\/         SET  SYSPROG=${security_groups_sysProg}/" \
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
  print_error_and_exit "Error ZWEL0159E: Failed to modify ${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(ZWESECUR)" "" 159
fi
print_trace "- ensure ${tmpfile} encoding before copying into data set"
ensure_file_encoding "${tmpfile}" "SPDX-License-Identifier"
print_trace "- ${tmpfile} created, copy to ${jcllib}(${tmpdsm})"
copy_to_data_set "${tmpfile}" "${jcllib}(${tmpdsm})" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}"
code=$?
print_trace "- Delete ${tmpfile}"
rm -f "${tmpfile}"
if [ ${code} -ne 0 ]; then
  print_error_and_exit "Error ZWEL0160E: Failed to write to ${jcllib}(${tmpdsm}). Please check if target data set is opened by others." "" 160
fi
print_message "- ${jcllib}(${tmpdsm}) is prepared"
print_message

###############################
# submit job
job_has_failures=
if [ "${ZWE_CLI_PARAMETER_SECURITY_DRY_RUN}" = "true" ]; then
  print_message "Dry-run mode, security setup is NOT performed on the system."
  print_message "Please submit ${jcllib}(${tmpdsm}) manually."
else
  print_message "Submit ${jcllib}(${tmpdsm})"
  jobid=$(submit_job "//'${jcllib}(${tmpdsm})'")
  code=$?
  if [ ${code} -ne 0 ]; then
    job_has_failures=true
    if [ "${ZWE_CLI_PARAMETER_IGNORE_SECURITY_FAILURES}" = "true" ]; then
      print_error "Warning ZWEL0161W: Failed to run JCL ${jcllib}(${tmpdsm})."
      # skip wait for job status step
      jobid=
    else
      print_error_and_exit "Error ZWEL0161E: Failed to run JCL ${jcllib}(${tmpdsm})." "" 161
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
  print_level2_message "Zowe security configurations are applied successfully."
fi
fi
