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

jcllib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.jcllib")
does_jcl_exist=$(is_data_set_exists "${jcllib}(ZWECSVSM)")
if [ "${does_jcl_exist}" = "false" ]; then
  zwecli_inline_execute_command init generate
fi
does_jcl_exist=$(is_data_set_exists "${jcllib}(ZWECSVSM)")
if [ "${does_jcl_exist}" = "false" ]; then
  print_error_and_exit "Error ZWEL0999E: ${jcllib}(ZWECSVSM) does not exist, cannot run. Run 'zwe init', 'zwe init generate', or submit JCL ${prefix}.SZWESAMP(ZWEGENER) before running this command." "" 999
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

# VSAM cache cannot be overwritten, must delete manually
# FIXME: cat cannot be used to test VSAM data set
vsam_existence=$(is_data_set_exists "${vsam_name}")
if [ "${vsam_existence}" = "true" ]; then
  if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}" = "true" ]; then
    # delete blindly and ignore errors
    result=$(tso_command delete "'${vsam_name}'")
  fi
  else
    # error
    print_error_and_exit "Error ZWEL0158E: ${vsam_name} already exists." "" 158
  fi
fi

 
jcl_file=$(create_tmp_file)
copy_mvs_to_uss "${jcllib}(ZWECSVSM)" "${jcl_file}"
jcl_contents=$(cat "${jcl_file}")

print_message "Template JCL: ${prefix}.SZWESAMP(ZWECSVSM) , Executable JCL: ${jcllib}(ZWECSVSM)"
print_message "--- JCL Content ---"
print_message "$jcl_contents"
print_message "--- End of JCL ---"

if [ -z "${ZWE_CLI_PARAMETER_DRY_RUN}" ]; then
    print_message "Submitting Job ZWECSVSM"
    jobid=$(submit_job $jcl_file)
    code=$?
    if [ ${code} -ne 0 ]; then
      print_error_and_exit "Error ZWEL0161E: Failed to run JCL ${jcllib}(ZWECSVSM)." "" 161
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
        print_level2_message "Zowe Caching Service VSAM storage is created successfully."
    else
        print_error_and_exit "Error ZWEL0163E: Job ${jobname}(${jobid}) ends with code ${jobcccode} (${jobcctext})." "" 163
    fi
else
    print_message "JCL not submitted, command run with dry run flag."
    print_message "To perform command, re-run command without dry run flag, or submit the JCL directly"
    print_level2_message "Command run successfully."
    rm $jcl_file
fi
