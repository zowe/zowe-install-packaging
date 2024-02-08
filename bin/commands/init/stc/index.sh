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

print_level1_message "Install Zowe main started task"

###############################
# validation
require_zowe_yaml

# read prefix and validate
prefix=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.prefix")
if [ -z "${prefix}" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file." "" 157
fi

# read PROCLIB and validate
proclib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.proclib")
if [ -z "${proclib}" ]; then
  print_error_and_exit "Error ZWEL0157E: PROCLIB (zowe.setup.dataset.proclib) is not defined in Zowe YAML configuration file." "" 157
fi

jcllib=$(verify_generated_jcl)

security_stcs_zowe=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.stcs.zowe")
if [ -z "${security_stcs_zowe}" ]; then
  print_error_and_exit "Error ZWEL0157E: (zowe.setup.security.stcs.zowe) is not defined in Zowe YAML configuration file." "" 157
fi
security_stcs_zis=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.stcs.zis")
if [ -z "${security_stcs_zis}" ]; then
  print_error_and_exit "Error ZWEL0157E: (zowe.setup.security.stcs.zis) is not defined in Zowe YAML configuration file." "" 157
fi
security_stcs_aux=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.stcs.aux")
if [ -z "${security_stcs_aux}" ]; then
  print_error_and_exit "Error ZWEL0157E: (zowe.setup.security.stcs.aux) is not defined in Zowe YAML configuration file." "" 157
fi
target_proclibs="${security_stcs_zowe} ${security_stcs_zis} ${security_stcs_aux}"

for mb in ${target_proclibs}; do
  # STCs in target proclib
  stc_existence=$(is_data_set_exists "${proclib}(${mb})")
  if [ "${stc_existence}" = "true" ]; then
    if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}" = "true" ]; then
      print_message "Warning ZWEL0300W: ${proclib}(${mb}) already exists. This data set member will be overwritten during configuration."
    else
      print_message "Warning ZWEL0301W: ${proclib}(${mb}) already exists and will not be overwritten. For upgrades, you must use --allow-overwrite."
    fi
  fi
done

if [ "${stc_existence}" = "true" ] &&  [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}" != "true" ]; then
  print_message "Skipped writing to ${proclib}. To write, you must use --allow-overwrite."
else

  jcl_file=$(create_tmp_file)
  copy_mvs_to_uss "${jcllib}(ZWEISTC)" "${jcl_file}"

  # TODO limitation... if STC names are default, JCL IEBCOPY wont work,
  #   because in member selection argument, the "rename" operation cannot be from/to the same name.
  #   yet if we don't have the rename option, then name customization wont work either!
  #   so, we have to have some conditional logic somewhere. until figuring out how to fix this in ZWEGENER, i am putting it here...
  jcl_edit=$(cat "${jcl_file}" | sed "s/ZWESLSTC,ZWESLSTC/ZWESLSTC/" | sed "s/ZWESISTC,ZWESISTC/ZWESISTC/" | sed "s/ZWESASTC,ZWESASTC/ZWESASTC/")
  echo "${jcl_edit}" > "${jcl_file}"

  print_and_handle_jcl "${jcl_file}" "ZWEISTC" "${jcllib}" "${prefix}" "true"
  print_level2_message "Zowe main started tasks are installed successfully."
fi


