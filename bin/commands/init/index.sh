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

# Check if we can update node/java home, or runtime dir.
# Only possible right now if the config is a basic file.
# no FILE() or PARMLIB() syntax can be handled here yet.
if [ -e "${ZWE_CLI_PARAMETER_CONFIG}" ]; then
  update_node_home=
  found_node_home="$(shell_read_yaml_node_home "${ZWE_CLI_PARAMETER_CONFIG}")"
  # only try to update if it's not defined
  if [ -z "${found_node_home}" ]; then
    update_node_home=$(detect_node_home)
  fi

  update_java_home=
  found_java_home="$(shell_read_yaml_java_home "${ZWE_CLI_PARAMETER_CONFIG}")"
  # only try to update if it's not defined
  if [ -z "${found_java_home}" ]; then
    update_java_home=$(detect_java_home)
  fi

  update_zowe_runtime_dir=
  # do we have zowe.runtimeDirectory defined in zowe.yaml?
  yaml_runtime_dir=$(shell_read_yaml_config "${ZWE_CLI_PARAMETER_CONFIG}" "zowe" "runtimeDirectory")
  if [ -z "${yaml_runtime_dir}" ]; then
    update_zowe_runtime_dir="${ZWE_zowe_runtimeDirectory}"
  fi

  if [ -n "${update_node_home}" -o -n "${update_java_home}" -o -n "${update_zowe_runtime_dir}" ]; then
    if [ "${ZWE_CLI_PARAMETER_UPDATE_CONFIG}" = "true" ]; then
      if [ -n "${update_node_home}" ]; then
        update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "node.home" "${update_node_home}"
      fi
      if [ -n "${update_java_home}" ]; then
        update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "java.home" "${update_java_home}"
      fi
      if [ -n "${update_zowe_runtime_dir}" ]; then
        update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.runtimeDirectory" "${update_zowe_runtime_dir}"
      fi

      print_level2_message "Runtime directory, Java and/or node.js settings are updated successfully."
    else
      print_message "These configurations need to be added to your YAML configuration file:"
      print_message ""
      if [ -n "${update_zowe_runtime_dir}" ]; then
        print_message "zowe:"
        print_message "  runtimeDirectory: \"${update_zowe_runtime_dir}\""
      fi
      if [ -n "${update_node_home}" ]; then
        print_message "node:"
        print_message "  home: \"${update_node_home}\""
      fi
      if [ -n "${update_java_home}" ]; then
        print_message "java:"
        print_message "  home: \"${update_java_home}\""
      fi

      print_level2_message "Please manually update \"${ZWE_CLI_PARAMETER_CONFIG}\" before you start Zowe."
    fi
  fi
fi

USE_CONFIGMGR=$(check_configmgr_enabled)
if [ "${USE_CONFIGMGR}" = "true" ]; then
  if [ -z "${ZWE_PRIVATE_TMP_MERGED_YAML_DIR}" ]; then

    # user-facing command, use tmpdir to not mess up workspace permissions
    export ZWE_PRIVATE_TMP_MERGED_YAML_DIR=1
  fi
  _CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/init/cli.js"
else
  print_error_and_exit "Error ZWEL0316E: Command requires zowe.useConfigmgr=true to use." "" 316
fi
