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
  # zwe command allows to use parameter without value:
  #   zwe install --ds-prefix ---> ZWE_CLI_PARAMETER_DATASET_PREFIX=""
  # To go thru "DS Prefix" code, we have to use test -n ${var+foo}
  if [ -n "${ZWE_CLI_PARAMETER_DATASET_PREFIX+foo}" ]; then
    _CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/install/clix.js"
  else
    if [ -z "${ZWE_PRIVATE_TMP_MERGED_YAML_DIR}" ]; then
      # user-facing command, use tmpdir to not mess up workspace permissions
      export ZWE_PRIVATE_TMP_MERGED_YAML_DIR=1
    fi
    if [ -n "${ZWE_CLI_PARAMETER_CONFIG}" ]; then
      _CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/install/cli.js"
    else
      print_error_and_exit "Error ZWEL0108E: Zowe YAML config file is required." "" 108
    fi
  fi
else

print_level0_message "Install Zowe MVS data sets"

###############################
# constants
# keep in sync with workflows/templates/smpe-install/ZWE3ALOC.vtl
cust_ds_list="${ZWE_PRIVATE_DS_SZWESAMP}|Zowe sample library|dsntype(library) dsorg(po) recfm(f b) lrecl(80) unit(sysallda) space(15,15) tracks
${ZWE_PRIVATE_DS_SZWEAUTH}|Zowe authorized load library|dsntype(library) dsorg(po) recfm(u) lrecl(0) blksize(32760) unit(sysallda) space(30,15) tracks
${ZWE_PRIVATE_DS_SZWELOAD}|Zowe load library|dsntype(library) dsorg(po) recfm(u) lrecl(0) blksize(32760) unit(sysallda) space(30,15) tracks
${ZWE_PRIVATE_DS_SZWEEXEC}|Zowe executable utilities library|dsntype(library) dsorg(po) recfm(f b) lrecl(80) unit(sysallda) space(15,15) tracks"

###############################
# validation
if [ -n "${ZWE_CLI_PARAMETER_DATASET_PREFIX+foo}" ]; then
  prefix="${ZWE_CLI_PARAMETER_DATASET_PREFIX}"
  prefix_validate=$(echo "${prefix}" | tr '[:lower:]' '[:upper:]' | grep -E '^([A-Z\$\#\@]){1}([A-Z0-9\$\#\@\-]){0,7}(\.([A-Z\$\#\@]){1}([A-Z0-9\$\#\@\-]){0,7}){0,11}$')
  if [ -z "${prefix_validate}" ]; then
    print_error_and_exit "Error ZWEL0102E: Invalid parameter --dataset-prefix=\"${prefix}\"." "" 102
  fi
else
  require_zowe_yaml
  # read prefix and validate
  prefix=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.prefix")
  if [ -z "${prefix}" ]; then
    print_error_and_exit "Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file." "" 157
  fi
fi

###############################
# create data sets if they do not exist
print_message "Create MVS data sets if they do not exist"
ds_count=0
while read -r line; do
  ds=$(echo "${line}" | awk -F"|" '{print $1}')
  name=$(echo "${line}" | awk -F"|" '{print $2}')
  spec=$(echo "${line}" | awk -F"|" '{print $3}')
  # check existence
  ds_existence=$(is_data_set_exists "${prefix}.${ds}")
  if [ "${ds_existence}" = "true" ]; then
    if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}" = "true" ]; then
      print_message "Warning ZWEL0300W: ${prefix}.${ds} already exists. Members in this data set will be overwritten."
    else
      print_message "Warning ZWEL0301W: ${prefix}.${ds} already exists and will not be overwritten. For upgrades, you must use --allow-overwrite."
      ds_count=$(( $ds_count + 1 ))
    fi
  else
    print_message "Creating ${name} - ${prefix}.${ds}"
    create_data_set "${prefix}.${ds}" "${spec}"
    if [ $? -ne 0 ]; then
      print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
    fi
  fi
done <<EOF
$(echo "${cust_ds_list}")
EOF

print_message

if [ "${ds_count}" = "4" ]; then
  print_level1_message "Zowe MVS data sets installation skipped. For upgrades, you must use --allow-overwrite."
else
  ###############################
  # copy members
  cd "${ZWE_zowe_runtimeDirectory}/files/${ZWE_PRIVATE_DS_SZWESAMP}"
  for mb in $(find . -type f); do
    base_mb=$(basename ${mb})
    print_message "Copy files/${ZWE_PRIVATE_DS_SZWESAMP}/(${base_mb}) to ${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(${base_mb})"
    copy_to_data_set "${mb}" "${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(${base_mb})" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}"
    if [ $? -ne 0 ]; then
      print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
    fi
  done

  cd "${ZWE_zowe_runtimeDirectory}/files/${ZWE_PRIVATE_DS_SZWEEXEC}"
  for mb in $(find . -type f); do
    base_mb=$(basename ${mb})
    print_message "Copy files/${ZWE_PRIVATE_DS_SZWEEXEC}/(${base_mb}) to ${prefix}.${ZWE_PRIVATE_DS_SZWEEXEC}(${base_mb})"
    copy_to_data_set "${mb}" "${prefix}.${ZWE_PRIVATE_DS_SZWEEXEC}(${base_mb})" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}"
    if [ $? -ne 0 ]; then
      print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
    fi
  done
  
  # prepare MVS for launcher
  cd "${ZWE_zowe_runtimeDirectory}/components/launcher"
  print_message "Copy components/launcher/samplib/ZWESLSTC to ${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(ZWESLSTC)"
  copy_to_data_set "samplib/ZWESLSTC" "${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(ZWESLSTC)" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
  fi
  
  print_message "Copy components/launcher/bin/zowe_launcher to ${prefix}.${ZWE_PRIVATE_DS_SZWEAUTH}(ZWELNCH)"
  copy_to_data_set "bin/zowe_launcher" "${prefix}.${ZWE_PRIVATE_DS_SZWEAUTH}(ZWELNCH)" "-X" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
  fi

  # copy in configmgr rexx edition
  cd "${ZWE_zowe_runtimeDirectory}/files/${ZWE_PRIVATE_DS_SZWELOAD}"
  for mb in $(find . -type f); do
    base_mb=$(basename ${mb})
    print_message "Copy files/${ZWE_PRIVATE_DS_SZWELOAD}/(${base_mb}) to ${prefix}.${ZWE_PRIVATE_DS_SZWELOAD}(${base_mb})"
    copy_to_data_set "${mb}" "${prefix}.${ZWE_PRIVATE_DS_SZWELOAD}(${base_mb})" "-X" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}"
    if [ $? -ne 0 ]; then
      print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
    fi
  done
  
  # FIXME: move these parts to zss commands.install?
  cd "${ZWE_zowe_runtimeDirectory}/components/zss"
  zss_samplib="ZWESAUX=ZWESASTC ZWESIP00 ZWESIS01=ZWESISTC ZWESISCH"
  for mb in ${zss_samplib}; do
    mb_from=$(echo "${mb}" | awk -F= '{print $1}')
    mb_to=$(echo "${mb}" | awk -F= '{print $2}')
    if [ -z "${mb_to}" ]; then
      mb_to="${mb_from}"
    fi
    print_message "Copy components/zss/SAMPLIB/${mb_from} to ${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(${mb_to})"
    copy_to_data_set "SAMPLIB/${mb_from}" "${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(${mb_to})" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}"
    if [ $? -ne 0 ]; then
      print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
    fi
  done
  
  zss_loadlib="ZWESIS01 ZWESAUX ZWESISDL"
  for mb in ${zss_loadlib}; do
    print_message "Copy components/zss/LOADLIB/${mb} to ${prefix}.${ZWE_PRIVATE_DS_SZWEAUTH}(${mb})"
    copy_to_data_set "LOADLIB/${mb}" "${prefix}.${ZWE_PRIVATE_DS_SZWEAUTH}(${mb})" "-X" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}"
    if [ $? -ne 0 ]; then
      print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
    fi
  done
  
  print_message

  ###############################
  # exit message
  print_level1_message "Zowe MVS data sets are installed successfully."
fi

print_message "Zowe installation completed. In order to use Zowe, you need to run \"zwe init\" command to initialize Zowe instance."
print_message "- Type \"zwe init --help\" to get more information."
print_message
print_message "You can also run individual init sub-commands: mvs, certificate, security, vsam, apfauth, and stc."
print_message "- Type \"zwe init <sub-command> --help\" (for example, \"zwe init stc --help\") to get more information."
print_message

fi
