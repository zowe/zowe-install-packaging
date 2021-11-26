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

print_level0_message "Install Zowe MVS datasets"

###############################
# constants
sizeAUTH='space(30,15) tracks'
sizeSAMP='space(15,15) tracks'

###############################
# validation
require_zowe_yaml

# read HLQ and validate
hlq=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.install.mvs.hlq")
if [ -z "${hlq}" -o "${hlq}" = "null" ]; then
  print_error_and_exit "Error ZWEI0157E: HLQ (zowe.install.mvs.hlq) is not defined in Zowe YAML configuration file." "" 157
fi

# check existence
samplib_existence=$(is_dataset_exists "${hlq}.SZWESAMP")
authlib_existence=$(is_dataset_exists "${hlq}.SZWEAUTH")
if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}" = "true" ]; then
  # warning
  if [ "${samplib_existence}" = "true" ]; then
    print_message "Warning ZWEI0158W: ${hlq}.SZWESAMP already exists. Members in this dataset will be overwritten during install."
  fi
  if [ "${authlib_existence}" = "true" ]; then
    print_message "Warning ZWEI0159W: ${hlq}.SZWEAUTH already exists. Members in this dataset will be overwritten during install."
  fi
else
  # error
  if [ "${samplib_existence}" = "true" ]; then
    print_error_and_exit "Error ZWEI0158E: ${hlq}.SZWESAMP already exists. Installation aborts." "" 158
  fi
  if [ "${authlib_existence}" = "true" ]; then
    print_error_and_exit "Error ZWEI0159E: ${hlq}.SZWEAUTH already exists. Installation aborts." "" 159
  fi
fi

###############################
# create datasets if they are not exist
if [ "${samplib_existence}" != "true" ]; then
  print_message "Creating ${hlq}.SZWESAMP"
  create_dataset "${hlq}.SZWESAMP" "dsntype(library) dsorg(po) recfm(f b) lrecl(80) unit(sysallda) $sizeSAMP"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEI0111E: Command aborts with error." "" 111
  fi
fi
if [ "${authlib_existence}" != "true" ]; then
  print_message "Creating ${hlq}.SZWEAUTH"
  create_dataset "${hlq}.SZWEAUTH" "dsntype(library) dsorg(po) recfm(u) lrecl(0) blksize(32760) unit(sysallda) $sizeAUTH"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEI0111E: Command aborts with error." "" 111
  fi
fi

###############################
# copy members
cd "${ZWE_zowe_runtimeDirectory}/files/samplib"
for mb in $(find . -type f); do
  print_message "Copy files/samplib/$(basename ${mb}) to ${hlq}.SZWESAMP"
  copy_to_dataset "${mb}" "${hlq}.SZWESAMP" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEI0111E: Command aborts with error." "" 111
  fi
done

# FIXME: move these parts to zss commands.install
cd "${ZWE_zowe_runtimeDirectory}/components/zss"
zss_samplib="ZWESAUX ZWESIP00 ZWESIS01 ZWESISCH ZWESIPRG"
for mb in ${zss_samplib}; do
  print_message "Copy components/zss/${mb} to ${hlq}.SZWEAUTH"
  copy_to_dataset "SAMPLIB/${mb}" "${hlq}.SZWESAMP" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEI0111E: Command aborts with error." "" 111
  fi
done
zss_loadlib="ZWESIS01 ZWESAUX"
for mb in ${zss_loadlib}; do
  print_message "Copy components/zss/${mb} to ${hlq}.SZWEAUTH"
  copy_to_dataset "LOADLIB/${mb}" "${hlq}.SZWEAUTH" "-X" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEI0111E: Command aborts with error." "" 111
  fi
done

###############################
# exit message
print_message
print_level1_message "Zowe MVS datasets is installed successfully."
