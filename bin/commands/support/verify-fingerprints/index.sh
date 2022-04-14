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

print_level0_message "Verify Zowe file fingerprints"

###############################
# constants
tmp_file_prefix=zwe-support-verify-fingerprints
ZWE_VERSION=$(shell_read_json_config "${ZWE_zowe_runtimeDirectory}/manifest.json" 'version' 'version')

clean_up_tmp_files() {
  print_debug "- Clean up temporary files..."
  if [ -n "${all_files}" ]; then
    rm -f "${all_files}"
  fi
  if [ -n "${cust_hashes}" ]; then
    rm -f "${cust_hashes}"
  fi
}

###############################
# validation
require_java

if [ -z "${ZWE_VERSION}" ]; then
  print_error_and_exit "Error ZWEL0113E: Failed to find Zowe version. Please validate your Zowe directory." "" 113
fi
if [ ! -f "${ZWE_zowe_runtimeDirectory}/bin/utils/HashFiles.class" ]; then
  print_error_and_exit "Error ZWEL0150E: Failed to find file bin/utils/HashFiles.class. Zowe runtimeDirectory is invalid." "" 150
fi
if [ ! -f "${ZWE_zowe_runtimeDirectory}/fingerprint/RefRuntimeHash-${ZWE_VERSION}.txt" ]; then
  print_error_and_exit "Error ZWEL0150E: Failed to find file fingerprint/RefRuntimeHash-${ZWE_VERSION}.txt. Zowe runtimeDirectory is invalid." "" 150
fi

###############################
cd "${ZWE_zowe_runtimeDirectory}"

print_message "- Create Zowe directory file list"
all_files=$(create_tmp_file "${tmp_file_prefix}")
find . -name ./SMPE          -prune \
    -o -name "./ZWE*"        -prune \
    -o -name ./fingerprint   -prune \
    -o -type f -print > "${all_files}"
if [ ! -f "${all_files}" ]; then
  print_error "  * Error ZWEL0151E: Failed to create temporary file ${all_files}. Please check permission or volume free space."
  clean_up_tmp_files
  exit 151
fi
chmod 700 "${all_files}"
print_debug "  * File list created as ${all_files}"

print_message "- Calculate hashes of Zowe files"
cust_hashes=$(create_tmp_file "${tmp_file_prefix}")
result=$(java -cp "${ZWE_zowe_runtimeDirectory}/bin/utils/" HashFiles "${all_files}" | sort > "${cust_hashes}")
code=$?
if [ ${code} -eq 1 -o ! -f "${cust_hashes}" ]; then
  print_error "  * Error ZWEL0151E: Failed to create temporary file ${cust_hashes}. Please check permission or volume free space."
  print_error "  * Exit code: ${code}"
  print_error "  * Output:"
  if [ -n "${result}" ]; then
    print_error "$(padding_left "${result}" "    ")"
  fi
  clean_up_tmp_files
  exit 151
fi
chmod 700 "${cust_hashes}"
print_debug "  * Zowe file hashes created as ${cust_hashes}"

verify_failed=
while read -r step; do
  comm_param=$(echo "${step}" | awk '{print $1}')
  step_name=$(echo "${step}" | awk '{print $2}')

  print_message "- Find ${step_name} files"
  result=$(comm -${comm_param} "${ZWE_zowe_runtimeDirectory}/fingerprint/RefRuntimeHash-${ZWE_VERSION}.txt" "${cust_hashes}")
  if [ ${code} -eq 1 ]; then
    print_error "  * Error ZWEL0151E: Failed to compare hashes of fingerprint/RefRuntimeHash-${ZWE_VERSION}.txt and current."
    print_error "  * Exit code: ${code}"
    print_error "  * Output:"
    if [ -n "${result}" ]; then
      print_error "$(padding_left "${result}" "    ")"
    fi
    clean_up_tmp_files
    exit 151
  fi

  cnt=$(printf "${result}" | wc -l | awk '{print $1}')
  print_message "  * Number of ${step_name} files: ${cnt}"

  if [ ${cnt} -gt 0 ]; then
    verify_failed=true
    if [ "${ZWE_PRIVATE_LOG_LEVEL_ZWELS}" = "TRACE" ]; then
      print_trace "  * All ${step_name} files:"
      print_trace "${result}"
    elif [ "${ZWE_PRIVATE_LOG_LEVEL_ZWELS}" = "DEBUG" ]; then
      print_debug "  * First 10 ${step_name} files:" "console"
      head_10_result=$(echo "${result}" | head -n 10 | awk '{ print $1 }')
      print_debug "$(padding_left "${head_10_result}" "    ")" "console"
    fi
  fi
done <<EOF
3 different
13 extra
23 missing
EOF

###############################
# clean up
clean_up_tmp_files

###############################
# exit message
if [ -z "${verify_failed}" ]; then
  print_level1_message "Zowe file fingerprints verification passed."
else
  print_message
  print_error_and_exit "Error ZWEL0181E: Failed to verify Zowe file fingerprints." "" 181
fi
