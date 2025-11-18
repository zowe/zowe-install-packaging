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

CONFIGMGR_SYNTAX=$(check_configmgr_config_syntax)
validate_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}"
USE_JCL=$(check_jcl_enabled)
if [ "${USE_JCL}" = "true" ]; then
  if [ -z "${ZWE_PRIVATE_TMP_MERGED_YAML_DIR}" ]; then

    # user-facing command, use tmpdir to not mess up workspace permissions
    export ZWE_PRIVATE_TMP_MERGED_YAML_DIR=1
  fi
  _CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF),HEAPPOOLS64(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/init/mvs/cli.js"
elif [ "${CONFIGMGR_SYNTAX}" = "true" ]; then
  print_error_and_exit "Error ZWEL0115E: This command was submitted with FILE() or PARMLIB() syntax, which is only supported when JCL is also enabled." "" 115
else

###############################
# Old 3.2 code follows

    

print_level1_message "Initialize Zowe custom data sets"

###############################
# constants
cust_ds_list="parmlib|Zowe parameter library|dsntype(library) dsorg(po) recfm(f b) lrecl(80) unit(sysallda) space(15,15) tracks
jcllib|Zowe JCL library|dsntype(library) dsorg(po) recfm(f b) lrecl(80) unit(sysallda) space(15,15) tracks
authLoadlib|Zowe authorized load library|dsntype(library) dsorg(po) recfm(u) lrecl(0) blksize(32760) unit(sysallda) space(30,15) tracks
authPluginLib|Zowe authorized plugin library|dsntype(library) dsorg(po) recfm(u) lrecl(0) blksize(32760) unit(sysallda) space(30,15) tracks"
DRY_RUN=
if [ -n "${ZWE_CLI_PARAMETER_DRY_RUN}" ] || [ -n "${ZWE_CLI_PARAMETER_SECURITY_DRY_RUN}" ]; then
  DRY_RUN="true"
fi

# read prefix and validate
prefix=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.prefix")
if [ -z "${prefix}" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file." "" 157
fi

###############################
# create data sets if they do not exist
print_message "Create data sets if they do not exist"
while read -r line; do
  key=$(echo "${line}" | awk -F"|" '{print $1}')
  name=$(echo "${line}" | awk -F"|" '{print $2}')
  spec=$(echo "${line}" | awk -F"|" '{print $3}')
  
  # read def and validate
  ds=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.${key}")
  if [ -z "${ds}" ]; then
    # authLoadlib can be empty
    if [ "${key}" = "authLoadlib" ]; then
      continue
    else
      print_error_and_exit "Error ZWEL0157E: ${name} (zowe.setup.dataset.${key}) is not defined in Zowe YAML configuration file." "" 157
    fi
  fi
  # check existence
  ds_existence=$(is_data_set_exists "${ds}")
  if [ "${ds_existence}" = "true" ]; then
    any_existence="true"
    if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}" = "true" ]; then
      # warning
      print_message "Warning ZWEL0300W: ${ds} already exists. This dataset will be overwritten."
    else
      # print_error_and_exit "Error ZWEL0158E: ${ds} already exists." "" 158
      # warning
      print_message "Warning ZWEL0301W: ${ds} already exists and will not be overwritten. For upgrades, you must use --allow-overwrite."
    fi
  else
    print_message "Creating ${ds}"
    if [ -z "${DRY_RUN}" ]; then
      create_data_set "${ds}" "${spec}"
      if [ $? -ne 0 ]; then
        print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
      fi
    else
      print_message "Skipping creating ${ds} due to --dry-run parameter."
    fi
  fi
done <<EOF
$(echo "${cust_ds_list}")
EOF
print_message

if [ "${any_existence}" = "true" ] && [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}" != "true" ]; then
  print_message "Skipped writing, you must use --allow-overwrite."
else
  ###############################
  # copy sample lib members
  parmlib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.parmlib")
  for mb in ZWESIP00; do
    print_message "Copy ${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(${mb}) to ${parmlib}(${mb})"
    if [ -z "${DRY_RUN}" ]; then
      data_set_copy_to_data_set "${prefix}" "${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(${mb})" "${parmlib}(${mb})" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}"
      if [ $? -ne 0 ]; then
        print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
      fi
    else
      print_message "Skipping copy operation due to --dry-run parameter."
    fi
  done

  ###############################
  # copy auth lib members
  authLoadlib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.authLoadlib")
  if [ -n "${authLoadlib}" ]; then
    for mb in ZWESIS01 ZWESAUX ZWESISDL; do
      print_message "Copy components/zss/LOADLIB/${mb} to ${authLoadlib}(${mb})"
      if [ -z "${DRY_RUN}" ]; then
        copy_to_data_set "${ZWE_zowe_runtimeDirectory}/components/zss/LOADLIB/${mb}" "${authLoadlib}(${mb})" "-X" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}"
        if [ $? -ne 0 ]; then
          print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
        fi
      else
        print_message "Skipping copy operation due to --dry-run parameter."  
      fi
    done
    for mb in ZWELNCH; do
      print_message "Copy components/launcher/bin/zowe_launcher to ${authLoadlib}(${mb})"
      if [ -z "${DRY_RUN}" ]; then
        copy_to_data_set "${ZWE_zowe_runtimeDirectory}/components/launcher/bin/zowe_launcher" "${authLoadlib}(${mb})" "-X" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}"
        if [ $? -ne 0 ]; then
          print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
        fi
      else
        print_message "Skipping copy operation due to --dry-run parameter."
      fi
    done
  fi
fi

###############################
# exit message
print_level2_message "Zowe custom data sets are initialized successfully."
fi
