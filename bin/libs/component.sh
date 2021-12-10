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

################################################################################
# @internal 

get_component_manifest() {
  component_dir=$1

  if [ -f "${component_dir}/manifest.yaml" ]; then
    echo "${component_dir}/manifest.yaml"
  elif [ -f "${component_dir}/manifest.yml" ]; then
    echo "${component_dir}/manifest.yml"
  elif [ -f "${component_dir}/manifest.json" ]; then
    echo "${component_dir}/manifest.json"
  fi
}

###############################
# Find component root directory
#
# Required environment variables:
# - ZWE_zowe_runtimeDirectory
#
# Optional environment variables:
# - ZWE_zowe_extensionDirectory
#
# This function will find the component in this sequence:
#   - check if component id parameter is a path to lifecycle scripts directory
#   - ${ZWE_zowe_runtimeDirectory}/components/<component-id>
#   - ${ZWE_zowe_extensionDirectory}/<component-id>
#
# @param string     component id, or path to component lifecycle scripts
# Output            component directory will be written to stdout
find_component_directory() {
  component_id=$1
  # find component lifecycle scripts directory
  component_dir=

  if [ -d "${ZWE_zowe_runtimeDirectory}/components/${component_id}" ]; then
    # this is a Zowe build-in component
    component_dir="${ZWE_zowe_runtimeDirectory}/components/${component_id}"
  elif [ -n "${ZWE_zowe_extensionDirectory}" ]; then
    if [ -d "${ZWE_zowe_extensionDirectory}/${component_id}" ]; then
      # this is an extension installed/linked in ZWE_zowe_extensionDirectory
      component_dir="${ZWE_zowe_extensionDirectory}/${component_id}"
    fi
  elif [ -n "${ZWE_zowe_extensionDirectories}" ]; then
    for extension_dir in $(echo "${ZWE_zowe_extensionDirectories}" | sed 's/,/ /g'); do
      if [ -d "${extension_dir}/${component_id}" ]; then
        # this is an extension installed/linked in ZWE_zowe_extensionDirectories
        component_dir="${extension_dir}/${component_id}"
      fi
    done
  fi

  echo "${component_dir}"
}

###############################
# Read component manifest
#
# Note: this function requires node, which means NODE_HOME should have been defined,
#       and ensure_node_is_on_path should have been executed.
#
# Required environment variables:
# - ZWE_zowe_runtimeDirectory
# - NODE_HOME
#
# Optional environment variables:
# - ZWE_PRIVATE_WORKSPACE_ENV_DIR
#
# Example:
# - read my-component commands.start value
#   read_component_manifest "/path/to/zowe/components/my-component" ".commands.start"
#
# @param string   component directory
# @param string   string of manifest key. For example: ".commands.configure"
# Output          empty if component doesn't have manifest
#                          , or manifest doesn't have the key
#                          , or NODE_HOME is not defined
#                 the value defined in the manifest of the selected key
read_component_manifest() {
  component_dir=$1
  manifest_key=$2

  if [ -f "${component_dir}/manifest.yaml" ]; then
    read_yaml "${component_dir}/manifest.yaml" "${manifest_key}"
    return $?
  elif [ -f "${component_dir}/manifest.yml" ]; then
    read_yaml "${component_dir}/manifest.yml" "${manifest_key}"
    return $?
  elif [ -f "${component_dir}/manifest.json" ]; then
    read_json "${component_dir}/manifest.json" "${manifest_key}"
    return $?
  else
    print_error_and_exit "Error ZWEL0132E: No manifest file found in module ${component_dir}." "" 132
  fi
}

###############################
# Detect and verify component manifest encoding
#
# Note: this function always returns 0 and if succeeds, it will output encoding
#       to stdout.
#
# Example:
# - detect manifest encoding of my-component
#   detect_component_manifest_encoding "/path/to/zowe/components/my-component"
#
# @param string   component directory
detect_component_manifest_encoding() {
  component_dir=$1

  component_manifest=$(get_component_manifest "${component_dir}")
  if [ -n "${component_manifest}" ]; then
    # manifest at least should have name defined
    confirmed_encoding=$(detect_file_encoding "${component_manifest}" "name")
    if [ -n "${confirmed_encoding}" ]; then
      echo "${confirmed_encoding}"
    fi
  fi
}

detect_if_component_tagged() {
  component_dir=$1

  component_manifest=$(get_component_manifest "${component_dir}")
  if [ -n "${component_manifest}" ]; then
      # manifest at least should have name defined
    tag=$(chtag -p ${component_manifest} | cut -f 2 -d\ )
    if [ ! "${tag}" = "untagged" ]; then
      echo "true"
    else
      echo "false"
    fi
  fi
}

find_all_installed_components() {
  components=

  # iterate <runtime>/components
  for component in $(find_sub_directories "${ZWE_zowe_runtimeDirectory}/components"); do
    component_dir="${ZWE_zowe_runtimeDirectory}/components/${component}"
    if [ -f "${component_dir}/manifest.yaml" -o -f "${component_dir}/manifest.yml" -o -f "${component_dir}/manifest.json" ]; then
      if [ -n "${components}" ]; then
        components="${components},"
      fi
      components="${components}${component}"
    fi
  done

  if [ -n "${ZWE_zowe_extensionDirectory}" ]; then
    for component in $(find_sub_directories "${ZWE_zowe_extensionDirectory}"); do
      component_dir="${ZWE_zowe_extensionDirectory}/${component}"
      if [ -f "${component_dir}/manifest.yaml" -o -f "${component_dir}/manifest.yml" -o -f "${component_dir}/manifest.json" ]; then
        if [ -n "${components}" ]; then
          components="${components},"
        fi
        components="${components}${component}"
      fi
    done
  fi

  if [ -n "${ZWE_zowe_extensionDirectories}" ]; then
    for extension_dir in $(echo "${ZWE_zowe_extensionDirectories}" | sed 's/,/ /g'); do
      for component in $(find_sub_directories "${extension_dir}"); do
        component_dir="${extension_dir}/${component}"
        if [ -f "${component_dir}/manifest.yaml" -o -f "${component_dir}/manifest.yml" -o -f "${component_dir}/manifest.json" ]; then
          if [ -n "${components}" ]; then
            components="${components},"
          fi
          components="${components}${component}"
        fi
      done
    done
  fi

  echo "${components}"
}

find_all_enabled_components() {
  components=

  for component in $(echo "${ZWE_INSTALLED_COMPONENTS}" | sed 's/,/ /g'); do
    sanitized_component_name=$(echo "${component}" | sanitize_alphanum)
    enabled_var="ZWE_components_${sanitized_component_name}_enabled"
    enabled=$(get_var_value "${enabled_var}")
    if [ "${enabled}" = "true" ]; then
      if [ -n "${components}" ]; then
        components="${components},"
      fi
      components="${components}${component}"
    fi
  done

  echo "${components}"
}

###############################
# Parse and process manifest service APIML static definition
#
# The supported manifest entry is ".apimlServices.static[].file". All files defined
# here will be parsed and put into Zowe static definition directory in IBM-850 encoding.
#
# Note: this function requires node, which means NODE_HOME should have been defined,
#       and ensure_node_is_on_path should have been executed.
#
# Required environment variables:
# - ZWE_zowe_runtimeDirectory
# - NODE_HOME
# - ZWE_CLI_PARAMETER_HA_INSTANCE
# - ZWE_STATIC_DEFINITIONS_DIR
#
# @param string   component directory
process_component_apiml_static_definitions() {
  component_dir=$1

  if [ -z "${ZWE_STATIC_DEFINITIONS_DIR}" ]; then
    print_error "Error: ZWE_STATIC_DEFINITIONS_DIR is required to process component definitions for API Mediation Layer."
    return 1
  fi

  component_name=$(basename "${component_dir}")
  all_succeed=true

  static_defs=$(read_component_manifest "${component_dir}" ".apimlServices.static[].file" 2>/dev/null)
  if [ -z "${static_defs}" -o "${static_defs}" = "null" ]; then
    # does the component define it as object instead of array
    static_defs=$(read_component_manifest "${component_dir}" ".apimlServices.static.file" 2>/dev/null)
  fi

  cd "${component_dir}"
  while read -r one_def; do
    one_def_trimmed=$(echo "${one_def}" | xargs)
    if [ -n "${one_def_trimmed}" -a "${one_def_trimmed}" != "null" ]; then
      if [ ! -r "${one_def}" ]; then
        print_error "static definition file ${one_def} of component ${component_name} is not accessible"
        all_succeed=false
        break
      fi

      echo "process ${component_name} service static definition file ${one_def_trimmed} ..."
      sanitized_def_name=$(echo "${one_def_trimmed}" | sed 's/[^a-zA-Z0-9]/_/g')
      # FIXME: we may change the static definitions files to real template in the future.
      #        currently we support to use environment variables in the static definition template
      parsed_def=$( ( echo "cat <<EOF" ; cat "${one_def}" ; echo ; echo EOF ) | sh 2>&1)
      retval=$?
      if [ "${retval}" != "0" ]; then
        print_error "failed to parse ${component_name} API Mediation Layer static definition file ${one_def}: ${parsed_def}"
        if [[ "${parsed_def}" == *unclosed* ]]; then
          print_error "this is very likely an encoding issue that file is not tagged properly"
        fi
        all_succeed=false
        break
      fi
      print_debug "- writing ${ZWE_STATIC_DEFINITIONS_DIR}/${component_name}.${sanitized_def_name}.${ZWE_CLI_PARAMETER_HA_INSTANCE}.yml"
      if [ "${ZWE_RUN_ON_ZOS}" = "true" ]; then
        echo "${parsed_def}" | iconv -f IBM-1047 -t IBM-850 > ${ZWE_STATIC_DEFINITIONS_DIR}/${component_name}.${sanitized_def_name}.${ZWE_CLI_PARAMETER_HA_INSTANCE}.yml
      else
        echo "${parsed_def}" > ${ZWE_STATIC_DEFINITIONS_DIR}/${component_name}.${sanitized_def_name}.${ZWE_CLI_PARAMETER_HA_INSTANCE}.yml
      fi
      chmod 770 ${ZWE_STATIC_DEFINITIONS_DIR}/${component_name}.${sanitized_def_name}.${ZWE_CLI_PARAMETER_HA_INSTANCE}.yml
    fi
  done <<EOF
$(echo "${static_defs}")
EOF

  if [ "${all_succeed}" = "true" ]; then
    return 0
  else
    # error message should have be echoed before this
    return 1
  fi
}

###############################
# Parse and process manifest App Framework Plugin (appfwPlugins) definitions
#
# The supported manifest entry is ".appfwPlugins". All plugins
# defined will be passed to install-app.sh for proper installation.
#
# Note: this function requires node, which means NODE_HOME should have been defined,
#       and ensure_node_is_on_path should have been executed.
#
# @param string   component directory
process_component_appfw_plugin() {
  component_dir=$1

  all_succeed=true
  iterator_index=0
  appfw_plugin_path=$(read_component_manifest "${component_dir}" ".appfwPlugins[${iterator_index}].path" 2>/dev/null)
  while [ "${appfw_plugin_path}" != "null" ] && [ -n "${appfw_plugin_path}" ]; do
    cd "${component_dir}"

    # apply values if appfw_plugin_path has variables
    appfw_plugin_path=$(parse_string_vars "${appfw_plugin_path}")
    appfw_plugin_path=$(cd "${appfw_plugin_path}"; pwd)

    if [ ! -r "${appfw_plugin_path}" ]; then
      print_error "App Framework plugin directory ${appfw_plugin_path} is not accessible"
      all_succeed=false
      break
    fi
    if [ ! -r "${appfw_plugin_path}/pluginDefinition.json" ]; then
      print_error "App Framework plugin directory ${appfw_plugin_path} does not have pluginDefinition.json"
      all_succeed=false
      break
    fi
    appfw_plugin_id=$(read_json "${appfw_plugin_path}/pluginDefinition.json" ".identifier")
    if [ -z "${appfw_plugin_id}" -o "${appfw_plugin_id}" = "null" ]; then
      print_error "Cannot read identifier from App Framework plugin ${appfw_plugin_path}/pluginDefinition.json"
      all_succeed=false
      break
    fi

    # copy to workspace/app-server/pluginDirs
    appfw_plugin_workspace_path="${ZWE_zowe_workspaceDirectory}/app-server/pluginDirs/${appfw_plugin_id}"
    mkdir -p "${appfw_plugin_workspace_path}"
    cp -r "${appfw_plugin_path}/." "${appfw_plugin_workspace_path}/"

    # install app
    "${ZWE_zowe_runtimeDirectory}/components/app-server/share/zlux-app-server/bin/install-app.sh" "${appfw_plugin_workspace_path}"
    # FIXME: do we know if install-app.sh fails. if so, we need to set all_succeed=false

    iterator_index=`expr $iterator_index + 1`
    appfw_plugin_path=$(read_component_manifest "${component_dir}" ".appfwPlugins[${iterator_index}].path" 2>/dev/null)
  done

  if [ "${all_succeed}" = "true" ]; then
    return 0
  else
    # error message should have be echoed before this
    return 1
  fi
}

###############################
# Parse and process manifest Gateway Shared Libs (gatewaySharedLibs) definitions
#
# The supported manifest entry is ".gatewaySharedLibs". All shared libs
# defined will be passed to install-app.sh for proper installation.
#
# Note: this function requires node, which means NODE_HOME should have been defined,
#       and ensure_node_is_on_path should have been executed.
#
# @param string   component directory
process_component_gateway_shared_libs() {
  component_dir=$1

  all_succeed=true
  iterator_index=0
  plugin_id=
  gateway_shared_libs_workspace_path=
  gateway_shared_libs_path=$(read_component_manifest "${component_dir}" ".gatewaySharedLibs[${iterator_index}]" 2>/dev/null)
  while [ "${gateway_shared_libs_path}" != "null" ] && [ -n "${gateway_shared_libs_path}" ]; do
    cd "${component_dir}"

    if [ -z "${plugin_id}" ]; then
      # prepare plugin directory
      plugin_id=$(read_component_manifest "${component_dir}" ".id" 2>/dev/null)
      gateway_shared_libs_workspace_path="${ZWE_zowe_workspaceDirectory}/gateway/sharedLibs/${plugin_id}"
      mkdir -p "${gateway_shared_libs_workspace_path}"
    fi

    # copy to workspace/gateway/sharedLibs/
    if [ -f "${gateway_shared_libs_path}" ]; then
      gateway_shared_libs_path_dir=$(dirname "${gateway_shared_libs_path}")
      if [ "${gateway_shared_libs_path_dir}" = "." ]; then
        cp "${gateway_shared_libs_path}" "${gateway_shared_libs_workspace_path}"
      else
        mkdir -p "${gateway_shared_libs_workspace_path}/${gateway_shared_libs_path_dir}"
        cp "${gateway_shared_libs_path}" "${gateway_shared_libs_workspace_path}/${gateway_shared_libs_path_dir}"
      fi
    elif [ -d "${gateway_shared_libs_path}" ]; then
      mkdir -p "${gateway_shared_libs_workspace_path}/${gateway_shared_libs_path}"
      cp -r "${gateway_shared_libs_path}/." "${gateway_shared_libs_workspace_path}/${gateway_shared_libs_path}"
    else
      print_error "Gateway shared libs directory ${gateway_shared_libs_path} is not accessible"
      all_succeed=false
      break
    fi

    iterator_index=`expr $iterator_index + 1`
    gateway_shared_libs_path=$(read_component_manifest "${component_dir}" ".gatewaySharedLibs[${iterator_index}]" 2>/dev/null)
  done

  if [ "${all_succeed}" = "true" ]; then
    return 0
  else
    # error message should have be echoed before this
    return 1
  fi
}
