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
size_szweauth='space(30,15) tracks'
size_szwesamp='space(15,15) tracks'
size_szwclib='space(15,15) tracks'
size_jcllib='space(15,15) tracks'

###############################
# validation
require_zowe_yaml

# read HLQ and validate
hlq=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.mvs.hlq")
if [ -z "${hlq}" -o "${hlq}" = "null" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe HLQ (zowe.setup.mvs.hlq) is not defined in Zowe YAML configuration file." "" 157
fi

# check existence
authlib_existence=$(is_data_set_exists "${hlq}.${ZWE_DS_SZWEAUTH}")
samplib_existence=$(is_data_set_exists "${hlq}.${ZWE_DS_SZWESAMP}")
clib_existence=$(is_data_set_exists "${hlq}.${ZWE_DS_SZWCLIB}")
jcllib_existence=$(is_data_set_exists "${hlq}.${ZWE_DS_JCLLIB}")
if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}" = "true" ]; then
  # warning
  if [ "${authlib_existence}" = "true" ]; then
    print_message "Warning ZWEL0158W: ${hlq}.${ZWE_DS_SZWEAUTH} already exists. Members in this data set will be overwritten during install."
  fi
  if [ "${samplib_existence}" = "true" ]; then
    print_message "Warning ZWEL0158W: ${hlq}.${ZWE_DS_SZWESAMP} already exists. Members in this data set will be overwritten during install."
  fi
  if [ "${clib_existence}" = "true" ]; then
    print_message "Warning ZWEL0158W: ${hlq}.${ZWE_DS_SZWCLIB} already exists. Members in this data set will be overwritten during install."
  fi
  if [ "${jcllib_existence}" = "true" ]; then
    print_message "Warning ZWEL0158W: ${hlq}.${ZWE_DS_JCLLIB} already exists. Members in this data set will be overwritten during install."
  fi
else
  # error
  if [ "${authlib_existence}" = "true" ]; then
    print_error_and_exit "Error ZWEL0158E: ${hlq}.${ZWE_DS_SZWEAUTH} already exists. Installation aborts." "" 158
  fi
  if [ "${samplib_existence}" = "true" ]; then
    print_error_and_exit "Error ZWEL0158E: ${hlq}.${ZWE_DS_SZWESAMP} already exists. Installation aborts." "" 158
  fi
  if [ "${clib_existence}" = "true" ]; then
    print_error_and_exit "Error ZWEL0158E: ${hlq}.${ZWE_DS_SZWCLIB} already exists. Installation aborts." "" 158
  fi
  if [ "${jcllib_existence}" = "true" ]; then
    print_error_and_exit "Error ZWEL0158E: ${hlq}.${ZWE_DS_JCLLIB} already exists. Installation aborts." "" 158
  fi
fi

###############################
# create data sets if they are not exist
if [ "${authlib_existence}" != "true" ]; then
  print_message "Creating ${hlq}.${ZWE_DS_SZWEAUTH}"
  create_data_set "${hlq}.${ZWE_DS_SZWEAUTH}" "dsntype(library) dsorg(po) recfm(u) lrecl(0) blksize(32760) unit(sysallda) $size_szweauth"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
  fi
fi
if [ "${samplib_existence}" != "true" ]; then
  print_message "Creating ${hlq}.${ZWE_DS_SZWESAMP}"
  create_data_set "${hlq}.${ZWE_DS_SZWESAMP}" "dsntype(library) dsorg(po) recfm(f b) lrecl(80) unit(sysallda) $size_szwesamp"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
  fi
fi
if [ "${clib_existence}" != "true" ]; then
  print_message "Creating ${hlq}.${ZWE_DS_SZWCLIB}"
  create_data_set "${hlq}.${ZWE_DS_SZWCLIB}" "dsntype(library) dsorg(po) recfm(f b) lrecl(80) unit(sysallda) $size_szwclib"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
  fi
fi
if [ "${jcllib_existence}" != "true" ]; then
  print_message "Creating ${hlq}.${ZWE_DS_JCLLIB}"
  create_data_set "${hlq}.${ZWE_DS_JCLLIB}" "dsntype(library) dsorg(po) recfm(f b) lrecl(80) unit(sysallda) $size_jcllib"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
  fi
fi

###############################
# copy members
cd "${ZWE_zowe_runtimeDirectory}/files/${ZWE_DS_SZWESAMP}"
for mb in $(find . -type f); do
  print_message "Copy files/${ZWE_DS_SZWESAMP}/$(basename ${mb}) to ${hlq}.SZWESAMP"
  copy_to_data_set "${mb}" "${hlq}.SZWESAMP" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
  fi
done

cd "${ZWE_zowe_runtimeDirectory}/files/${ZWE_DS_SZWCLIB}"
for mb in $(find . -type f); do
  print_message "Copy files/${ZWE_DS_SZWCLIB}/$(basename ${mb}) to ${hlq}.${ZWE_DS_SZWCLIB}"
  copy_to_data_set "${mb}" "${hlq}.${ZWE_DS_SZWCLIB}" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
  fi
done

cd "${ZWE_zowe_runtimeDirectory}/files/${ZWE_DS_JCLLIB}"
for mb in $(find . -type f); do
  print_message "Copy files/${ZWE_DS_JCLLIB}/$(basename ${mb}) to ${hlq}.${ZWE_DS_JCLLIB}"
  copy_to_data_set "${mb}" "${hlq}.${ZWE_DS_JCLLIB}" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
  fi
done

# FIXME: this is handled by Zowe launcher commands.install
cd "${ZWE_zowe_runtimeDirectory}/components/launcher"
print_message "Copy components/launcher/samplib/ZWESLSTC to ${hlq}.${ZWE_DS_SZWEAUTH}"
copy_to_data_set "samplib/ZWESLSTC" "${hlq}.SZWESAMP" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
if [ $? -ne 0 ]; then
  print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
fi

# FIXME: move these parts to zss commands.install
# FIXME: ZWESIPRG
cd "${ZWE_zowe_runtimeDirectory}/components/zss"
zss_samplib="ZWESAUX=ZWESASTC ZWESIP00 ZWESIS01=ZWESISTC ZWESISCH"
for mb in ${zss_samplib}; do
  mb_from=$(echo "${mb}" | awk -F= '{print $1}')
  mb_to=$(echo "${mb}" | awk -F= '{print $2}')
  if [ -z "${mb_to}" ]; then
    mb_to="${mb_from}"
  fi
  print_message "Copy components/zss/SAMPLIB/${mb_from} to ${hlq}.${ZWE_DS_SZWEAUTH}(${mb_to})"
  copy_to_data_set "SAMPLIB/${mb_from}" "${hlq}.SZWESAMP(${mb_to})" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
  fi
done
zss_loadlib="ZWESIS01 ZWESAUX"
for mb in ${zss_loadlib}; do
  print_message "Copy components/zss/LOADLIB/${mb} to ${hlq}.${ZWE_DS_SZWEAUTH}"
  copy_to_data_set "LOADLIB/${mb}" "${hlq}.${ZWE_DS_SZWEAUTH}" "-X" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0111E: Command aborts with error." "" 111
  fi
done

###############################
# exit message
print_message
print_level1_message "Zowe MVS data sets are installed successfully."
