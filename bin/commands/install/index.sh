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

print_level0_message "Install Zowe MVS data sets"

###############################
# constants
cust_ds_list="${ZWE_PRIVATE_DS_SZWESAMP}|Zowe sample library|dsntype(library) dsorg(po) recfm(f b) lrecl(80) unit(sysallda) space(15,15) tracks
${ZWE_PRIVATE_DS_SZWEAUTH}|Zowe authorized load library|dsntype(library) dsorg(po) recfm(u) lrecl(0) blksize(32760) unit(sysallda) space(30,15) tracks
${ZWE_PRIVATE_DS_SZWEEXEC}|Zowe executable utilities library|dsntype(library) dsorg(po) recfm(f b) lrecl(80) unit(sysallda) space(15,15) tracks"

###############################
# validation
if [ -n "${ZWE_CLI_PARAMETER_HLQ}" ]; then
  hlq="${ZWE_CLI_PARAMETER_HLQ}"
else
  require_zowe_yaml

  # read HLQ and validate
  hlq=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.mvs.hlq")
  if [ -z "${hlq}" ]; then
    print_error_and_exit "Error ZWEL0157E: Zowe HLQ (zowe.setup.mvs.hlq) is not defined in Zowe YAML configuration file." "" 157
  fi
fi

###############################
# create data sets if they are not exist
print_message "Create MVS data sets if they are not exist"
while read -r line; do
  ds=$(echo "${line}" | awk -F"|" '{print $1}')
  name=$(echo "${line}" | awk -F"|" '{print $2}')
  spec=$(echo "${line}" | awk -F"|" '{print $3}')
  
  # check existence
  ds_existence=$(is_data_set_exists "${hlq}.${ds}")
  if [ "${ds_existence}" = "true" ]; then
    if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}" = "true" ]; then
      # warning
      print_message "Warning ZWEL0300W: ${hlq}.${ds} already exists. Members in this data set will be overwritten."
    else
      # error
      print_error_and_exit "Error ZWEL0158E: ${hlq}.${ds} already exists." "" 158
    fi
  else
    print_message "Creating ${name} - ${hlq}.${ds}"
    create_data_set "${hlq}.${ds}" "${spec}"
    if [ $? -ne 0 ]; then
      print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
    fi
  fi
done <<EOF
$(echo "${cust_ds_list}")
EOF
print_message

###############################
# copy members
cd "${ZWE_zowe_runtimeDirectory}/files/${ZWE_PRIVATE_DS_SZWESAMP}"
for mb in $(find . -type f); do
  print_message "Copy files/${ZWE_PRIVATE_DS_SZWESAMP}/$(basename ${mb}) to ${hlq}.${ZWE_PRIVATE_DS_SZWESAMP}"
  copy_to_data_set "${mb}" "${hlq}.${ZWE_PRIVATE_DS_SZWESAMP}" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
  fi
done

cd "${ZWE_zowe_runtimeDirectory}/files/${ZWE_PRIVATE_DS_SZWEEXEC}"
for mb in $(find . -type f); do
  print_message "Copy files/${ZWE_PRIVATE_DS_SZWEEXEC}/$(basename ${mb}) to ${hlq}.${ZWE_PRIVATE_DS_SZWEEXEC}"
  copy_to_data_set "${mb}" "${hlq}.${ZWE_PRIVATE_DS_SZWEEXEC}" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
  fi
done

# prepare MVS for launcher
cd "${ZWE_zowe_runtimeDirectory}/components/launcher"
print_message "Copy components/launcher/samplib/ZWESLSTC to ${hlq}.${ZWE_PRIVATE_DS_SZWESAMP}"
copy_to_data_set "samplib/ZWESLSTC" "${hlq}.${ZWE_PRIVATE_DS_SZWESAMP}" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
if [ $? -ne 0 ]; then
  print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
fi
print_message "Copy components/launcher/bin/zowe_launcher to ${hlq}.${ZWE_PRIVATE_DS_SZWEAUTH}"
copy_to_data_set "bin/zowe_launcher" "${hlq}.${ZWE_PRIVATE_DS_SZWEAUTH}(ZWELNCH)" "-X" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
if [ $? -ne 0 ]; then
  print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
fi

# FIXME: move these parts to zss commands.install?
# FIXME: ZWESIPRG is in zowe-install-packaging
cd "${ZWE_zowe_runtimeDirectory}/components/zss"
zss_samplib="ZWESAUX=ZWESASTC ZWESIP00 ZWESIS01=ZWESISTC ZWESISCH"
for mb in ${zss_samplib}; do
  mb_from=$(echo "${mb}" | awk -F= '{print $1}')
  mb_to=$(echo "${mb}" | awk -F= '{print $2}')
  if [ -z "${mb_to}" ]; then
    mb_to="${mb_from}"
  fi
  print_message "Copy components/zss/SAMPLIB/${mb_from} to ${hlq}.${ZWE_PRIVATE_DS_SZWESAMP}(${mb_to})"
  copy_to_data_set "SAMPLIB/${mb_from}" "${hlq}.${ZWE_PRIVATE_DS_SZWESAMP}(${mb_to})" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
  fi
done
zss_loadlib="ZWESIS01 ZWESAUX"
for mb in ${zss_loadlib}; do
  print_message "Copy components/zss/LOADLIB/${mb} to ${hlq}.${ZWE_PRIVATE_DS_SZWEAUTH}"
  copy_to_data_set "LOADLIB/${mb}" "${hlq}.${ZWE_PRIVATE_DS_SZWEAUTH}" "-X" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
  fi
done
print_message

###############################
# exit message
print_level1_message "Zowe MVS data sets are installed successfully."

print_message "Zowe installation completed. In order to use Zowe, you need to run \"zwe init\" command to initialize Zowe instance."
print_message "- Type \"zwe init --help\" to get more information."
print_message
print_message "You can also run individual init sub-commands: mvs, certificate, security, vsam, apfauth, and stc."
print_message "- Type \"zwe init <sub-command> --help\" (for example, \"zwe init stc --help\") to get more information."
print_message
