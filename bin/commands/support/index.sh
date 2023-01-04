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

print_level0_message "Collect information for Zowe support"

###############################
# constants
DATE=`date +%Y-%m-%d-%H-%M-%S`
target_dir="${ZWE_CLI_PARAMETER_TARGET_DIR}"
if [ -z "${target_dir}" ]; then
  target_dir=$(get_tmp_dir)
else
  curr_pwd=$(pwd)
  cd "${target_dir}"
  target_dir=$(pwd)
  cd "${curr_pwd}"
fi
tmp_file_prefix=zwe-support
tmp_pax="${target_dir}/${tmp_file_prefix}.${DATE}.pax"
tmp_dir=$(create_tmp_file "${tmp_file_prefix}" "${target_dir}")

###############################
# validate
require_java
require_node
require_zowe_yaml

###############################
print_message "Started at ${DATE}"
mkdir "${tmp_dir}"
chmod 700 "${tmp_dir}"
print_debug "Temporary directory created: ${tmp_dir}"
print_message

###############################
print_level1_message "Collecting version of z/OS, Java, NodeJS"
VERSION_FILE="${tmp_dir}/version_output"
ZOS_VERSION=`operator_command "D IPLINFO" | grep -i release | xargs`
print_message "- z/OS: ${ZOS_VERSION}"
JAVA_VERSION=`${JAVA_HOME}/bin/java -version 2>&1 | head -n 1`
print_message "- Java: ${JAVA_VERSION}"
NODE_VERSION=`${NODE_HOME}/bin/node --version`
print_message "- NodeJS: ${NODE_VERSION}"
echo "z/OS version: ${ZOS_VERSION}" > "${VERSION_FILE}"
echo "Java version: ${JAVA_VERSION}" >> "${VERSION_FILE}"
echo "NodeJS version: ${NODE_VERSION}" >> "${VERSION_FILE}"
print_message

###############################
print_level1_message "Collecting Zowe configurations"
print_message "- manifest.json"
cp "${ZWE_zowe_runtimeDirectory}/manifest.json" "${tmp_dir}"
print_message "- zowe.yaml"
cp "${ZWE_CLI_PARAMETER_CONFIG}" "${tmp_dir}"
ZWE_zowe_workspaceDirectory=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.workspaceDirectory")
if [ -d "${ZWE_zowe_workspaceDirectory}/.env" ]; then
  print_message "- <workspace>/.env"
  mkdir -p "${tmp_dir}/workspace"
  cp -r "${ZWE_zowe_workspaceDirectory}/.env" "${tmp_dir}/workspace"
fi
if [ -d "${ZWE_zowe_workspaceDirectory}/api-mediation/api-defs" ]; then
  print_message "- <workspace>/api-mediation/api-defs"
  mkdir -p "${tmp_dir}/workspace"
  cp -r "${ZWE_zowe_workspaceDirectory}/api-mediation/api-defs" "${tmp_dir}/workspace"
fi
ZWE_zowe_setup_certificate_pkcs12_directory=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.pkcs12.directory")
if [ -d "${ZWE_zowe_setup_certificate_pkcs12_directory}" ]; then
  print_message "- ${ZWE_zowe_setup_certificate_pkcs12_directory}"
  mkdir -p "${tmp_dir}/keystore"
  cp -r "${ZWE_zowe_setup_certificate_pkcs12_directory}" "${tmp_dir}/keystore"
fi
print_message

###############################
print_level1_message "Collecting Zowe file fingerprints"
print_message "- copy original fingerprints"
cp -r "${ZWE_zowe_runtimeDirectory}/fingerprint" "${tmp_dir}"
print_message "- verify fingerprints"
result=$(export ZWE_PRIVATE_LOG_FILE="${tmp_dir}/verify-fingerprints.log" && export ZWE_PRIVATE_LOG_LEVEL_ZWELS=TRACE && touch "${ZWE_PRIVATE_LOG_FILE}" && . "${ZWE_zowe_runtimeDirectory}/bin/commands/support/verify-fingerprints/index.sh" 2>/dev/null 1>/dev/null)
print_message

###############################
job_name=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.job.name")
job_prefix=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.job.prefix")
print_level1_message "Collecting current process information based on the job prefix ${job_prefix} and job name ${job_name}"
PS_OUTPUT_FILE=${tmp_dir}"/ps_output"

# Collect process information
print_message "- Adding ${PS_OUTPUT_FILE}"
ps -A -o pid,ppid,time,etime,user,jobname,args | grep -e "^[[:space:]]*PID" -e "${job_prefix}" -e "${job_name}" > $PS_OUTPUT_FILE
print_message

###############################
# TODO: job log
# To avoid of using SDSF, we used to use TSO output command to export job log
# but it always fails with below error for me:
#   IKJ56328I JOB ZWE1SV REJECTED - JOBNAME MUST BE YOUR USERID OR MUST START WITH YOUR USERID
# REF: https://www.ibm.com/docs/en/zos/2.3.0?topic=subcommands-output-command
# REF: https://www.ibm.com/docs/en/zos/2.3.0?topic=ikj-ikj56328i

###############################
# Collect instance logs
log_dir=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.logDirectory")
print_level1_message "Collecting logs from ${log_dir}"
if [ -d "${log_dir}" ]; then
  cp -r "${log_dir}" "${tmp_dir}"
fi
print_message

###############################
print_level1_message "Create support package and clean up"
curr_pwd=$(pwd)
cd "${tmp_dir}"
pax -w -v -o saveext -f "${tmp_pax}" .
compress "${tmp_pax}"
chmod 700 "${tmp_pax}"*
cd "${curr_pwd}"
rm -fr "${tmp_dir}"
print_message

###############################
# exit message
print_level1_message "Zowe support package is generated as ${tmp_pax}.Z"
