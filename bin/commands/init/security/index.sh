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
# constants

###############################
# validation
require_zowe_yaml

# read HLQ and validate
hlq=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.mvs.hlq")
if [ -z "${hlq}" -o "${hlq}" = "null" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe HLQ (zowe.setup.mvs.hlq) is not defined in Zowe YAML configuration file." "" 157
fi
# read JCL library and validate
jcllib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.mvs.jcllib")
if [ -z "${jcllib}" -o "${jcllib}" = "null" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe custom JCL library (zowe.setup.mvs.jcllib) is not defined in Zowe YAML configuration file." "" 157
fi
security_product=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.product")
if [ -z "${security_product}" -o "${security_product}" = "null" ]; then
  security_product=RACF
fi
security_groups_admin=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.groups.admin")
if [ -z "${security_groups_admin}" -o "${security_groups_admin}" = "null" ]; then
  security_groups_admin=${ZWE_DEFAULT_ADMIN_GROUP}
fi
security_groups_stc=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.groups.stc")
if [ -z "${security_groups_stc}" -o "${security_groups_stc}" = "null" ]; then
  security_groups_stc=${ZWE_DEFAULT_ADMIN_GROUP}
fi
security_groups_sysProg=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.groups.sysProg")
if [ -z "${security_groups_sysProg}" -o "${security_groups_sysProg}" = "null" ]; then
  security_groups_sysProg=${ZWE_DEFAULT_ADMIN_GROUP}
fi
security_users_zowe=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.users.zowe")
if [ -z "${security_users_zowe}" -o "${security_users_zowe}" = "null" ]; then
  security_users_zowe=${ZWE_DEFAULT_ZOWE_USER}
fi
security_users_xmem=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.users.xmem")
if [ -z "${security_users_xmem}" -o "${security_users_xmem}" = "null" ]; then
  security_users_xmem=${ZWE_DEFAULT_XMEM_USER}
fi
security_users_aux=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.users.aux")
if [ -z "${security_users_aux}" -o "${security_users_aux}" = "null" ]; then
  security_users_aux=${ZWE_DEFAULT_XMEM_USER}
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

###############################
# prepare STCs
# ZWESLSTC
print_message "Modify ZWESECUR"
tmpfile=$(create_tmp_file $(echo "zwe ${ZWE_CLI_COMMANDS_LIST}" | sed "s# #-#g"))
tmpdsm=$(create_data_set_tmp_member "${jcllib}" "ZW$(date +%H%M)")
print_debug "- Copy ${hlq}.${ZWE_DS_SZWESAMP}(ZWESECUR) to ${tmpfile}"
# cat "//'IBMUSER.ZWEV2.SZWESAMP(ZWESECUR)'" | sed "s/^\\/\\/ \\+SET \\+PRODUCT=.*\\$/\\/\\         SET  PRODUCT=ACF2         * RACF, ACF2, or TSS/"
result=$(cat "//'${hlq}.${ZWE_DS_SZWESAMP}(ZWESECUR)'" | \
        sed  "s/^\/\/ \+SET \+PRODUCT=.*\$/\/\/         SET  PRODUCT=${security_product}/" | \
        sed "s/^\/\/ \+SET \+ADMINGRP=.*\$/\/\/         SET  ADMINGRP=${security_groups_admin}/" | \
        sed   "s/^\/\/ \+SET \+STCGRP=.*\$/\/\/         SET  STCGRP=${security_groups_stc}/" | \
        sed "s/^\/\/ \+SET \+ZOWEUSER=.*\$/\/\/         SET  ZOWEUSER=${security_users_zowe}/" | \
        sed "s/^\/\/ \+SET \+XMEMUSER=.*\$/\/\/         SET  XMEMUSER=${security_users_xmem}/" | \
        sed  "s/^\/\/ \+SET \+AUXUSER=.*\$/\/\/         SET  AUXUSER=${security_users_aux}/" | \
        sed  "s/^\/\/ \+SET \+ZOWESTC=.*\$/\/\/         SET  ZOWESTC=${security_stcs_zowe}/" | \
        sed  "s/^\/\/ \+SET \+XMEMSTC=.*\$/\/\/         SET  XMEMSTC=${security_stcs_xmem}/" | \
        sed   "s/^\/\/ \+SET \+AUXSTC=.*\$/\/\/         SET  AUXSTC=${security_stcs_aux}/" | \
        sed      "s/^\/\/ \+SET \+HLQ=.*\$/\/\/         SET  HLQ=${hlq}/" | \
        sed  "s/^\/\/ \+SET \+SYSPROG=.*\$/\/\/         SET  SYSPROG=${security_groups_sysProg}/" \
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
fi
if [ ! -f "${tmpfile}" ]; then
  print_error_and_exit "Error ZWEL0159E: Failed to modify ${hlq}.${ZWE_DS_SZWESAMP}(ZWESECUR)" "" 159
fi
print_trace "- ${tmpfile} created, copy to ${jcllib}(${tmpdsm})"
copy_to_data_set "${tmpfile}" "${jcllib}(${tmpdsm})" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
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
if [ "${ZWE_CLI_PARAMETER_SECURITY_DRY_RUN}" = "true" ]; then
  print_message "Dry-run mode, security setup is NOT performed on the system."
  print_message "Please submit ${jcllib}(${tmpdsm}) manually."
else
  print_message "Submit ${jcllib}(${tmpdsm})"
  jobid=$(submit_job "//'${jcllib}(${tmpdsm})'")
  code=$?
  if [ ${code} -ne 0 ]; then
    print_error_and_exit "Error ZWEL0161E: Failed to run JCL ${jcllib}(${tmpdsm})." "" 161
  fi
  print_debug "- job id ${jobid}"
  jobstate=$(wait_for_job "${jobid}")
  code=$?
  if [ ${code} -ne 0 ]; then
    print_error_and_exit "Error ZWEL0162E: Failed to find job ${jobid} result." "" 162
  fi
  jobname=$(echo "${jobstate}" | awk -F, '{print $2}')
  jobcctext=$(echo "${jobstate}" | awk -F, '{print $3}')
  jobcccode=$(echo "${jobstate}" | awk -F, '{print $4}')
  print_message "- Job ${jobname} ends with code ${jobcccode} (${jobcctext})."
fi

###############################
# exit message
print_level2_message "Zowe security configurations are applied successfully."
