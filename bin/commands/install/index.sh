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
  
# zwe command allows to use parameter without value:
#   zwe install --ds-prefix ---> ZWE_CLI_PARAMETER_DATASET_PREFIX=""
# To go thru "DS Prefix" code, we have to use test -n ${var+foo}

CEE_RO="XPLINK(ON),HEAPPOOLS(OFF),HEAPPOOLS64(OFF)"

# https://www.ibm.com/docs/en/zos/3.1.0?topic=descriptions-sh-invoke-shell
#   ${parameter+word}
#     Expands to word, provided that parameter is defined.

if [ -n "${ZWE_CLI_PARAMETER_DATASET_PREFIX+foo}" ]; then
  tmp_config=$(create_tmp_file)
  echo "zowe:" > "${tmp_config}"
  echo "  setup:" >> "${tmp_config}"
  echo "    dataset:" >> "${tmp_config}"
  echo "      prefix: ${ZWE_CLI_PARAMETER_DATASET_PREFIX}" >> "${tmp_config}"
  if [ -z "${ZWE_CLI_PARAMETER_CONFIG}" ]; then
    export ZWE_CLI_PARAMETER_CONFIG="${tmp_config}"
  else 
    # What if also --config is used?
    # Will ignore it or use it?
  fi
fi

if [ -z "${ZWE_PRIVATE_TMP_MERGED_YAML_DIR}" ]; then
  # user-facing command, use tmpdir to not mess up workspace permissions
  export ZWE_PRIVATE_TMP_MERGED_YAML_DIR=1
fi
if [ -n "${ZWE_CLI_PARAMETER_CONFIG}" ]; then
  _CEE_RUNOPTS="${CEE_RO}" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/install/cli.js"
  saveRC=$?
  if [ -n "${tmp_config}" ]; then
    rm "${tmp_config}"
  fi
  exit $saveRC
else
  print_error_and_exit "Error ZWEL0108E: Zowe YAML config file is required." "" 108
fi
