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

print_level1_message "APF authorize load libraries"

###############################
# constants
required_yaml_content="prefix authLoadlib authPluginLib"

###############################
# validation
require_zowe_yaml

for key in ${required_params}; do
  eval "${key}=$(read_yaml \"${ZWE_CLI_PARAMETER_CONFIG}\" \".zowe.setup.dataset.${key}\")"
  if [ -z "${key}" ]; then
      print_error_and_exit "Error ZWEL0157E: Dataset parameter (zowe.setup.dataset.${key}) is not defined in Zowe YAML configuration file." "" 157
  fi
done

jcllib=$(verify_generated_jcl)
if [ "$?" -eq 1 ]; then
  print_error_and_exit "Error ZWEL0999E: zowe.setup.dataset.jcllib does not exist, cannot run. Run 'zwe init', 'zwe init generate', or submit JCL ${prefix}.SZWESAMP(ZWEGENER) before running this command." "" 999
fi

print_and_handle_jcl "//'${jcllib}(ZWEIAPF)'" "ZWEIAPF" "${jcllib}" "${prefix}"
print_level2_message "Zowe load libraries are APF authorized successfully."
