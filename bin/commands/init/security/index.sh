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

print_level1_message "Run Zowe security configurations"

###############################
# validation
require_zowe_yaml

# read prefix and validate
prefix=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.prefix")
if [ -z "${prefix}" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file." "" 157
fi

jcllib=$(verify_generated_jcl)
if [ "$?" -eq 1 ]; then
  print_error_and_exit "Error ZWEL0999E: zowe.setup.dataset.jcllib does not exist, cannot run. Run 'zwe init', 'zwe init generate', or submit JCL ${prefix}.SZWESAMP(ZWEGENER) before running this command." "" 999
fi


validation_list="product groups.admin groups.stc groups.sysProg users.zowe users.zis stcs.zowe stcs.zis stcs.aux"

for item in ${validation_list}; do
  result=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.${item}")
  if [ -z "${result}" ]; then
    print_error_and_exit "Error ZWEL0157E: (zowe.setup.security.${item}) is not defined in Zowe YAML configuration file." "" 157
  fi
done

###############################
# submit job
print_and_handle_jcl "//'${jcllib}(ZWEI${security_product})'" "ZWEI${security_product}" "${jcllib}" "${prefix}" "false" "${ZWE_CLI_PARAMETER_IGNORE_SECURITY_FAILURES}"
print_message ""
print_message "WARNING: Due to the limitation of the ZWESECUR job, exit with 0 does not mean"
print_message "         the job is fully successful. Please check the job log to determine"
print_message "         if there are any inline errors."
print_message ""
print_level2_message "Command run successfully."




