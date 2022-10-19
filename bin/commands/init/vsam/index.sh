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
  _CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/init/vsam/cli.js"
else


print_level1_message "Create VSAM storage for Zowe Caching Service"

###############################
# constants

###############################
# validation
require_zowe_yaml

caching_storage=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".components.caching-service.storage.mode" | upper_case)
if [ "${caching_storage}" != "VSAM" ]; then
  print_error "Warning ZWEL0301W: Zowe Caching Service is not configured to use VSAM. Command skipped."
  return 0
fi

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
vsam_mode=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.vsam.mode")
if [ -z "${vsam_mode}" ]; then
  vsam_mode=NONRLS
fi
vsam_volume=
if [ "${vsam_mode}" = "NONRLS" ]; then
  vsam_volume=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.vsam.volume")
  if [ -z "${vsam_volume}" ]; then
    print_error_and_exit "Error ZWEL0157E: Zowe Caching Service VSAM data set Non-RLS volume (zowe.setup.vsam.volume) is not defined in Zowe YAML configuration file." "" 157
  fi
fi
vsam_storageClass=
if [ "${vsam_mode}" = "RLS" ]; then
  vsam_storageClass=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.vsam.storageClass")
  if [ -z "${vsam_storageClass}" ]; then
    print_error_and_exit "Error ZWEL0157E: Zowe Caching Service VSAM data set RLS storage class (zowe.setup.vsam.storageClass) is not defined in Zowe YAML configuration file." "" 157
  fi
fi
vsam_name=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".components.caching-service.storage.vsam.name")
if [ -z "${vsam_name}" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe Caching Service VSAM data set name (components.caching-service.storage.vsam.name) is not defined in Zowe YAML configuration file." "" 157
fi

jcl_existence=$(is_data_set_exists "${jcllib}(ZWECSVSM)")
if [ "${jcl_existence}" = "true" ]; then
  if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}" = "true" ]; then
    # warning
    print_message "Warning ZWEL0300W: ${jcllib}(ZWECSVSM) already exists. This data set member will be overwritten during configuration."
  else
    # print_error_and_exit "Error ZWEL0158E: ${jcllib}(ZWECSVSM) already exists." "" 158
    # warning
    print_message "Warning ZWEL0301W: ${jcllib}(ZWECSVSM) already exists and will not be overwritten. For upgrades, you must use --allow-overwrite."
  fi
fi

# VSAM cache cannot be overwritten, must delete manually
# FIXME: cat cannot be used to test VSAM data set
vsam_existence=$(is_data_set_exists "${vsam_name}")
if [ "${vsam_existence}" = "true" ]; then
  # error
  print_error_and_exit "Error ZWEL0158E: ${vsam_name} already exists." "" 158
fi
if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}" = "true" ]; then
  # delete blindly and ignore errors
  result=$(tso_command delete "'${vsam_name}'")
fi


if [ "${jcl_existence}" = "true" ] &&  [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}" != "true" ]; then
  print_message "Skipped writing to ${jcllib}(ZWECSVSM). To write, you must use --allow-overwrite."
else
  ###############################
  # prepare STCs
  # ZWESLSTC
  print_message "Modify ZWECSVSM"
  tmpfile=$(create_tmp_file $(echo "zwe ${ZWE_CLI_COMMANDS_LIST}" | sed "s# #-#g"))
  print_debug "- Copy ${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(ZWECSVSM) to ${tmpfile}"
  result=$(cat "//'${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(ZWECSVSM)'" | \
          sed  "s/^\/\/ \+SET \+MODE=.*\$/\/\/         SET  MODE=${vsam_mode}/" | \
          sed  "/^\/\/ALLOC/,9999s/#dsname/${vsam_name}/g" | \
          sed  "/^\/\/ALLOC/,9999s/#volume/${vsam_volume}/g" | \
          sed  "/^\/\/ALLOC/,9999s/#storclas/${vsam_storageClass}/g" \
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
    print_error_and_exit "Error ZWEL0159E: Failed to modify ${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(ZWECSVSM)" "" 159
  fi
  print_trace "- ${tmpfile} created with content"
  print_trace "$(cat "${tmpfile}")"
  print_trace "- ensure ${tmpfile} encoding before copying into data set"
  ensure_file_encoding "${tmpfile}" "SPDX-License-Identifier"
  print_trace "- copy to ${jcllib}(ZWECSVSM)"
  copy_to_data_set "${tmpfile}" "${jcllib}(ZWECSVSM)" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}"
  code=$?
  print_trace "- Delete ${tmpfile}"
  rm -f "${tmpfile}"
  if [ ${code} -ne 0 ]; then
    print_error_and_exit "Error ZWEL0160E: Failed to write to ${jcllib}(ZWECSVSM). Please check if target data set is opened by others." "" 160
  fi
  print_message "- ${jcllib}(ZWECSVSM) is prepared"
  print_message
fi

###############################
# submit job
print_message "Submit ${jcllib}(ZWECSVSM)"
jobid=$(submit_job "//'${jcllib}(ZWECSVSM)'")
code=$?
if [ ${code} -ne 0 ]; then
  print_error_and_exit "Error ZWEL0161E: Failed to run JCL ${jcllib}(ZWECSVSM)." "" 161
fi
print_debug "- job id ${jobid}"
jobstate=$(wait_for_job "${jobid}")
code=$?
if [ ${code} -eq 1 ]; then
  print_error_and_exit "Error ZWEL0162E: Failed to find job ${jobid} result." "" 162
fi
jobname=$(echo "${jobstate}" | awk -F, '{print $2}')
jobcctext=$(echo "${jobstate}" | awk -F, '{print $3}')
jobcccode=$(echo "${jobstate}" | awk -F, '{print $4}')
if [ ${code} -eq 0 ]; then
  print_message "- Job ${jobname}(${jobid}) ends with code ${jobcccode} (${jobcctext})."
else
  print_error_and_exit "Error ZWEL0163E: Job ${jobname}(${jobid}) ends with code ${jobcccode} (${jobcctext})." "" 163
fi

###############################
# exit message
print_level2_message "Zowe Caching Service VSAM storage is created successfully."
fi
