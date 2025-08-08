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
USE_JCL=$(check_jcl_enabled)
if [ "${USE_JCL}" = "true" ]; then
  if [ -z "${ZWE_PRIVATE_TMP_MERGED_YAML_DIR}" ]; then

    # user-facing command, use tmpdir to not mess up workspace permissions
    export ZWE_PRIVATE_TMP_MERGED_YAML_DIR=1
  fi
  _CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF),HEAPPOOLS64(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/init/apfauth/cli.js"
elif [ "${CONFIGMGR_SYNTAX}" = "true" ]; then
  print_error_and_exit "Error ZWEL0115E: This command was submitted with FILE() or PARMLIB() syntax, which is only supported when JCL is also enabled." "" 115
else

###############################
# Old 3.2 code follows



print_level1_message "APF authorize load libraries"

###############################
# constants
auth_libs="authLoadlib authPluginLib"
DRY_RUN=
if [ -n "${ZWE_CLI_PARAMETER_DRY_RUN}" ] || [ -n "${ZWE_CLI_PARAMETER_SECURITY_DRY_RUN}" ]; then
  DRY_RUN="true"
fi

###############################
# validation
require_zowe_yaml "skipnode"

# read prefix and validate
prefix=$(read_yaml_configmgr "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.prefix")
if [ -z "${prefix}" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file." "" 157
fi

###############################
# APF authorize loadlib
job_has_failures=
for key in ${auth_libs}; do
  # read def and validate
  ds=$(read_yaml_configmgr "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.${key}")
  if [ -z "${ds}" ]; then
    # authLoadlib can be empty
    if [ "${key}" = "authLoadlib" ]; then
      ds="${prefix}.${ZWE_PRIVATE_DS_SZWEAUTH}"
    else
      print_error_and_exit "Error ZWEL0157E: ${name} (zowe.setup.dataset.${key}) is not defined in Zowe YAML configuration file." "" 157
    fi
  fi

  print_message "APF authorize ${ds}"
  if [ -z "${DRY_RUN}" ]; then
    apf_authorize_data_set "${ds}"
    code=$?
    if [ $code -ne 0 ]; then
      if [ "${ZWE_CLI_PARAMETER_IGNORE_SECURITY_FAILURES}" = "true" ]; then
        job_has_failures=true
      else
        exit $code
      fi
    else
      print_debug "- APF authorized successfully."
    fi
  else
    print_message "Skipping APF authorize due to --dry-run parameter."
  fi
done

###############################
# exit message
if [ "${job_has_failures}" = "true" ]; then
  print_level2_message "Failed to APF authorize Zowe load libraries. Please check log for details."
else
  print_level2_message "Zowe load libraries are APF authorized successfully."
fi
fi
