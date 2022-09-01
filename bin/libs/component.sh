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
  component_dir="${1}"

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
  component_id="${1}"
  # find component lifecycle scripts directory
  component_dir=

  # init ZWE_zowe_extensionDirectory if it doesn't have a value
  if [ -z "${ZWE_zowe_extensionDirectory}" ]; then
    ZWE_zowe_extensionDirectory=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.extensionDirectory")
  fi
  if [ -z "${ZWE_zowe_extensionDirectories}" ]; then
    ZWE_zowe_extensionDirectories=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.extensionDirectories")
  fi

  if [ -d "${ZWE_zowe_runtimeDirectory}/components/${component_id}" ]; then
    # this is a Zowe build-in component
    component_dir="${ZWE_zowe_runtimeDirectory}/components/${component_id}"
  elif [ -n "${ZWE_zowe_extensionDirectory}" ]; then
    if [ -d "${ZWE_zowe_extensionDirectory}/${component_id}" ]; then
      # this is an extension installed/linked in ZWE_zowe_extensionDirectory
      component_dir="${ZWE_zowe_extensionDirectory}/${component_id}"
    fi
  elif [ -n "${ZWE_zowe_extensionDirectories}" ]; then
    # fix potential issue where ext dir has spaces
    while read -r extension_dir; do
      extension_dir=$(echo "${extension_dir}" | trim)
      if [ -n "${extension_dir}" -a -d "${extension_dir}/${component_id}" ]; then
        # this is an extension installed/linked in ZWE_zowe_extensionDirectories
        component_dir="${extension_dir}/${component_id}"
      fi
    done <<EOF
$(echo "${ZWE_zowe_extensionDirectories}" | tr "," "\n")
EOF
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
  component_dir="${1}"
  manifest_key="${2}"

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
    print_error_and_exit "Error ZWEL0132E: No manifest file found in component ${component_dir}." "" 132
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
  component_dir="${1}"

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
  component_dir="${1}"

  component_manifest=$(get_component_manifest "${component_dir}")
  if [ -n "${component_manifest}" ]; then
      # manifest at least should have name defined
    tag=$(get_file_encoding "${component_manifest}")
    if [ "${tag}" != "UNTAGGED" ]; then
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

  if [ -n "${ZWE_zowe_extensionDirectory}" -a -d "${ZWE_zowe_extensionDirectory}" ]; then
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
    while read -r extension_dir; do
      extension_dir=$(echo "${extension_dir}" | trim)
      if [ -n "${extension_dir}" -a -d "${extension_dir}" ]; then
        for component in $(find_sub_directories "${extension_dir}"); do
          component_dir="${extension_dir}/${component}"
          if [ -f "${component_dir}/manifest.yaml" -o -f "${component_dir}/manifest.yml" -o -f "${component_dir}/manifest.json" ]; then
            if [ -n "${components}" ]; then
              components="${components},"
            fi
            components="${components}${component}"
          fi
        done
      fi
    done <<EOF
$(echo "${ZWE_zowe_extensionDirectories}" | tr "," "\n")
EOF
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

find_all_launch_components() {
  components=

  for component in $(echo "${ZWE_ENABLED_COMPONENTS}" | sed 's/,/ /g'); do
    component_dir=$(find_component_directory "${component}")
    if [ -n "${component_dir}" ]; then
      start_script=$(read_component_manifest "${component_dir}" ".commands.start" 2>/dev/null)
      if [ -n "${start_script}" ]; then
        if [ -f "${component_dir}/${start_script}" ]; then
          if [ -n "${components}" ]; then
            components="${components},"
          fi
          components="${components}${component}"
        else
          print_error "Error ZWEL0172E: Component ${component} has commands.start defined but the file is missing."
        fi
      fi
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
  component_dir="${1}"

  if [ -z "${ZWE_STATIC_DEFINITIONS_DIR}" ]; then
    print_error "Error: ZWE_STATIC_DEFINITIONS_DIR is required to process component definitions for API Mediation Layer."
    return 1
  fi

  component_name=$(read_component_manifest "${component_dir}" ".name")
  all_succeed=true

  static_defs=$(read_component_manifest "${component_dir}" ".apimlServices.static[].file" 2>/dev/null)
  if [ -z "${static_defs}" ]; then
    # does the component define it as object instead of array
    static_defs=$(read_component_manifest "${component_dir}" ".apimlServices.static.file" 2>/dev/null)
  fi

  cd "${component_dir}"
  while read -r one_def; do
    one_def_trimmed=$(echo "${one_def}" | xargs)
    if [ -n "${one_def_trimmed}" ]; then
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
test_or_set_pc_bit() {
  path="${1}"

  testpc=`extattr $path | sed -n '3 p'`
  if [ "$testpc" = "Program controlled = YES" ]; then
    # normal
    return 0
  else
    echo "Plugin ZSS API not program controlled. Attempting to add PC bit." 
    extattr +p $path
    testpc2=$(extattr $path | sed -n '3 p')
    if [ "$testpc2" = "Program controlled = YES" ]; then
      echo "PC bit set successfully."
      return 0
    else
      echo "PC bit not set. This must be set such as by executing 'extattr +p ${path}' as a user with sufficient privilege."
      return 1
    fi
  fi
}

check_zss_pc_bit() {
  appfw_plugin_path=${1}

  services=$(read_json "${appfw_plugin_path}/pluginDefinition.json" ".dataServices" 2>/dev/null)
  if [ -n "${services}" ]; then
    echo "Checking ZSS services in plugin path=${1}"
    service_iterator_index=0
    service_type=$(read_json "${appfw_plugin_path}/pluginDefinition.json" ".dataServices[${service_iterator_index}].type" 2>/dev/null)
    while [ -n "${service_type}" ]; do
      if [ "${service_type}" = "service" ]; then
        libraryName31=$(read_json "${appfw_plugin_path}/pluginDefinition.json" ".dataServices[${service_iterator_index}].libraryName31" 2>/dev/null)
        libraryName64=$(read_json "${appfw_plugin_path}/pluginDefinition.json" ".dataServices[${service_iterator_index}].libraryName64" 2>/dev/null)
        libraryName=$(read_json "${appfw_plugin_path}/pluginDefinition.json" ".dataServices[${service_iterator_index}].libraryName" 2>/dev/null)
        if [ -n "${libraryName31}" ]; then
          test_or_set_pc_bit "${appfw_plugin_path}/lib/${libraryName31}"
          if [ "$?" = "1" ]; then
            break
          fi
        fi
        if [ -n "${libraryName64}" ]; then
          test_or_set_pc_bit "${appfw_plugin_path}/lib/${libraryName64}"
          if [ "$?" = "1" ]; then
            break
          fi
        fi
        if [ -n "${libraryName}" ]; then
          test_or_set_pc_bit "${appfw_plugin_path}/lib/${libraryName}"
          if [ "$?" = "1" ]; then
            break
          fi
        fi
      fi
      service_iterator_index=`expr $service_iterator_index + 1`
      service_type=$(read_json "${appfw_plugin_path}/pluginDefinition.json" ".dataServices[${service_iterator_index}].type 2>/dev/null")
    done
  fi
}

process_zss_plugin_install() {
  if [ "${ZWE_RUN_ON_ZOS}" = "true" ]; then
    print_trace "- Checking for zss plugins and verifying them"
    component_dir="${1}"

    iterator_index=0
    appfw_plugin_path=$(read_component_manifest "${component_dir}" ".appfwPlugins[${iterator_index}].path" 2>/dev/null)
    while [ -n "${appfw_plugin_path}" ]; do
      cd "${component_dir}"

      # apply values if appfw_plugin_path has variables
      appfw_plugin_path=$(parse_string_vars "${appfw_plugin_path}")
      appfw_plugin_path=$(cd "${appfw_plugin_path}"; pwd)

      check_zss_pc_bit "${appfw_plugin_path}"

      iterator_index=`expr $iterator_index + 1`
      appfw_plugin_path=$(read_component_manifest "${component_dir}" ".appfwPlugins[${iterator_index}].path" 2>/dev/null)
    done
  fi
}

process_zis_plugin_install() {
  if [ "${ZWE_RUN_ON_ZOS}" = "true" ]; then
    zwes_zis_pluginlib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.authPluginLib")
    zwes_zis_parmlib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.parmlib")
    zwes_zis_parmlib_member=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.parmlibMembers.zis")
    zwes_zis_parmlib_keys=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.zis.parmlib.keys")
    print_trace "- Checking for zis plugins and verifying them"
    component_dir="${1}"
    
    iterator_index=0
    zis_plugin_id=$(read_component_manifest "${component_dir}" ".zisPlugins[${iterator_index}].id" 2>/dev/null)
    zis_plugin_path=$(read_component_manifest "${component_dir}" ".zisPlugins[${iterator_index}].path" 2>/dev/null)
    print_trace "Attempting to install ZIS plugin ${zis_plugin_id} at ${zis_plugin_path}"
    while [ -n "${zis_plugin_path}" ]; do
      cd "${component_dir}"
      zis_plugin_install "${zis_plugin_path}" "${zwes_zis_pluginlib}" "${zwes_zis_parmlib}" "${zwes_zis_parmlib_member}" "${zis_plugin_id}" "${component_dir}" "${zwes_zis_parmlib_keys}"
      if [ $? -ne 0 ]; then
        print_message "Failed to install ZIS plugin: ${zis_plugin_id}"
        exit 1
      fi

      iterator_index=`expr $iterator_index + 1`
      zis_plugin_path=$(read_component_manifest "${component_dir}" ".zisPlugins[${iterator_index}].path" 2>/dev/null)
      zis_plugin_id=$(read_component_manifest "${component_dir}" ".zisPlugins[${iterator_index}].id" 2>/dev/null)
    done
  fi
}

# $1 = key-value pair
get_key_of_string() {
  echo "$1" | sed 's/=/ /g' | awk '{print $1}'
}

# $1 = key-value pair
get_value_of_string() {
  echo "$1" | sed 's/=/ /g' | awk '{print $2}'
}

# $1 = line number
# $2 = file
get_string_at_line_number() {
  awk -v n="$1" 'NR == n {print $0}' "$2"
}

# $1 = search_key
# $2 = file
get_line_number_of_key() {
  grep "$1" "$2" > /dev/null
  if [ $? -eq 0 ]; then
    awk -v s="$1" '$0 ~ s {print NR}' "$2"
  else
    echo ""
  fi
}

# $1 = line number
# $2 = file
remove_key_value_at_line_number() {
  mv "$2" "$2.tmp"
  awk -v n=$1 'NR != n' "$2.tmp" > "$2"
  rm -f "$2.tmp"
}

# $1 = key-value pair
# $2 = file
add_key_value_at_end_of_file() {
  key=$(get_key_of_string "$1")
  value=$(get_value_of_string "$1")
  resolved_value=$(resolve_env_parameter "$value") # Check for env variable substitution
  
  # Check if we recevied a non-empty value for the key (if the value has been
  # defined using an environmental variable).
  if [ "$resolved_value" = "VALUE_NOT_FOUND" ]; then
    print_error "Error ZWEL0203E: Env value in key-value pair $1 has not been defined."
    return 203
  fi
  echo "${key}=${resolved_value}" >> "$2"
}

zis_plugin_install() {
  plugin_path="${1}"
  zwes_zis_pluginlib="${2}"
  zwes_zis_parmlib="${3}"
  zwes_zis_parmlib_member="${4}"
  plugin_id="${5}"
  component_dir="${6}"
  zwes_zis_parmlib_keys="${7}"
  parmlib_member_as_unix_file=$(create_tmp_file "${zwes_zis_parmlib_member}")
  
  copy_mvs_to_uss "${zwes_zis_parmlib}(${zwes_zis_parmlib_member})" "${parmlib_member_as_unix_file}"

  changed=0
  
  base_path="${component_dir}/${plugin_path}"
  samplib_path="${base_path}/samplib"
  loadlib_path="${base_path}/loadlib"
  
  if [ -d "${base_path}" ]; then
    if [ -d "${loadlib_path}" ] && [ -d "${samplib_path}" ]; then
      for module in $(ls ${loadlib_path}); do # There isn't really a situation where we want to use ZWE_CLI_PARAMETER_ALLOW_OVERWRITE
        copy_to_data_set "${loadlib_path}/${module}" "$zwes_zis_pluginlib" "" "true"
        if [ $? != 0 ]; then
          print_error "Error ZWEL0200E: Failed to copy USS file ${loadlib_path}/${module} to MVS data set $zwes_zis_pluginlib." 
          return 200
        fi
      done
      for params in $(ls ${samplib_path}); do
        if [ ! -f "${samplib_path}/${params}" ]; then
          print_error "Error ZWEL0201E: File ${samplib_path}/${params} does not exist." 
          return 201
        fi
        while read samplib_key_value; do
          prefix=$(echo "$samplib_key_value" | cut -c -2)
          if [ "$prefix" = "//" ] || [ "$prefix" = "* " ] || [ "$prefix" = "" ]; then
            continue
          fi
          grep -x "$samplib_key_value" "$parmlib_member_as_unix_file" > /dev/null
          if [ $? -eq 0 ]; then
            print_message "The key-value pair $samplib_key_value is being skipped because it's already there and hasn't changed."
            continue
          else
            update_uss_parmlib_key_value "$samplib_key_value" "$parmlib_member_as_unix_file"
            if [ $? -ne 0 ]; then
              print_message "Failed to install ZIS plugin: ${zis_plugin_id}"
              exit 1
            fi
          fi
        done < "${samplib_path}/${params}"
      done
    fi
  print_message "Successfully installed ZIS plugin: ${plugin_id}"
  fi

  if [ $changed -eq 1 ]; then
    copy_to_data_set "$parmlib_member_as_unix_file" "$zwes_zis_parmlib($zwes_zis_parmlib_member)" "" "true"
  fi
}

update_uss_parmlib_key_value() {
  samplib_key_value="${1}"
  parmlib_member_as_unix_file="${2}"
  
  samplib_key=$(get_key_of_string "$samplib_key_value")
  if [ "$samplib_key" = "" ]; then
    print_error "Error ZWEL0202E: Unable to find samplib key for $samplib_key_value." 
    return 202
  fi
  # In the case of a key not being there, an empty string will be returned.
  num=$(get_line_number_of_key "$samplib_key" "$parmlib_member_as_unix_file")
  if [ "$num" != "" ]; then
    parsed_zwes_zis_parmlib_keys=$(replace "${zwes_zis_parmlib_keys}" "." "_") # replace . with _ in keyname for working key search
    parsed_samplib_key=$(replace "${samplib_key}" "." "_") # replace . with _ in keyname for working key search
    config_samplib_key_value=$(read_json_string ${parsed_zwes_zis_parmlib_keys} ".${parsed_samplib_key}")
    if [ "$config_samplib_key_value" = "list" ]; then
    # The key is comma separated list
      parmlib_key_value=$(get_string_at_line_number "$num" "$parmlib_member_as_unix_file")
      parmlib_value=$(get_value_of_string "$parmlib_key_value")
      samplib_value=$(get_value_of_string "$samplib_key_value")
      is_substr_of "$samplib_value" "$parmlib_value"
      if [ $? -eq 0 ]; then
        new_parmlib_key_value="$samplib_key=$parmlib_value,$samplib_value"
        remove_key_value_at_line_number $num "$parmlib_member_as_unix_file"
        add_key_value_at_end_of_file "$new_parmlib_key_value" "$parmlib_member_as_unix_file"
        changed=1
      fi
    else
      # The key is not special and the value is different.
      remove_key_value_at_line_number "$num" "$parmlib_member_as_unix_file"
      add_key_value_at_end_of_file "$samplib_key_value" "$parmlib_member_as_unix_file"
      changed=1
    fi
  else
    # The key doesn't exist. Just add the key-value pair to the end of the file.
    add_key_value_at_end_of_file "$samplib_key_value" "$parmlib_member_as_unix_file"
    changed=1
  fi
}

#################################################
# Try to resolve values that are defined using
# environmental variables, otherwise return
# the original value - borrowed from ZSS
#
# @param string   value
# Returns:
#   * If an env variable is provided, its value
#     is returned on success
#   * If an env variable is provided and
#     the variable is not defined,
#     string VALUE_NOT_FOUND is returned
#   * The original value is returned
#################################################
resolve_env_parameter() {

  parm=$1

  # Are we dealing with an env variable based value?
  # Yes, resolve the value using eval, otherwise return the value itself.
  if echo $parm | grep -q -E "^[$]{1}[A-Za-z0-9_]+$"; then
    ( eval "echo $parm" 2>/dev/null )
    if [ $? -ne 0 ]; then
      echo "VALUE_NOT_FOUND"
    fi
  else
    echo $parm
  fi

}

process_component_appfw_plugin() {
  print_trace "- Starting appfw plugin configure check"
  component_dir="${1}"

  all_succeed=true
  iterator_index=0
  appfw_plugin_path=$(read_component_manifest "${component_dir}" ".appfwPlugins[${iterator_index}].path" 2>/dev/null)
  while [ -n "${appfw_plugin_path}" ]; do
    cd "${component_dir}"

    # apply values if appfw_plugin_path has variables
    appfw_plugin_path=$(parse_string_vars "${appfw_plugin_path}")
    appfw_plugin_path=$(cd "${appfw_plugin_path}"; pwd)

    if [ ! -r "${appfw_plugin_path}/pluginDefinition.json" ]; then
      print_error "App Framework plugin directory ${appfw_plugin_path} does not have pluginDefinition.json"
      all_succeed=false
      break
    fi

    if [ "${ZWE_RUN_ON_ZOS}" != "true" ]; then
      # for containers, copy to workspace/app-server/pluginDirs and run install-app. on zos, this is done at startup.
      appfw_plugin_id=$(read_json "${appfw_plugin_path}/pluginDefinition.json" ".identifier")
      if [ -z "${appfw_plugin_id}" ]; then
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
    fi

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
  component_dir="${1}"

  # make sure $ZWE_GATEWAY_SHARED_LIBS exists
  mkdir -p "${ZWE_GATEWAY_SHARED_LIBS}"

  all_succeed=true
  iterator_index=0
  plugin_name=
  gateway_shared_libs_workspace_path=
  gateway_shared_libs_path=$(read_component_manifest "${component_dir}" ".gatewaySharedLibs[${iterator_index}]" 2>/dev/null)
  while [ -n "${gateway_shared_libs_path}" ]; do
    cd "${component_dir}"

    if [ -z "${plugin_name}" ]; then
      # prepare plugin directory
      plugin_name=$(read_component_manifest "${component_dir}" ".name" 2>/dev/null)
      if [ -z "${plugin_name}" ]; then
        print_error "Cannot read name from the plugin ${component_dir}"
        all_succeed=false
        break
      fi
      gateway_shared_libs_workspace_path="${ZWE_GATEWAY_SHARED_LIBS}/${plugin_name}"
      mkdir -p "${gateway_shared_libs_workspace_path}"
    fi

    # copy manifest to workspace
    component_manifest=$(get_component_manifest "${component_dir}")
    if [ ! -z "${component_manifest}" -a -f "${component_manifest}" ]; then
      cp "${component_manifest}" "${gateway_shared_libs_workspace_path}"
    fi

    # copy libraries to workspace/gateway/sharedLibs/<plugin-id>
    # Due to limitation of how Java loading shared libraries, all jars are copied to plugin root directly.
    if [ -f "${gateway_shared_libs_path}" ]; then
      cp "${gateway_shared_libs_path}" "${gateway_shared_libs_workspace_path}"
    elif [ -d "${gateway_shared_libs_path}" ]; then
      find "${gateway_shared_libs_path}" -type f | xargs -I{} cp {} "${gateway_shared_libs_workspace_path}"
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

###############################
# Parse and process manifest Discovery Shared Libs (discoverySharedLibs) definitions
#
# The supported manifest entry is ".discoverySharedLibs". All shared libs
# defined will be passed to install-app.sh for proper installation.
#
# Note: this function requires node, which means NODE_HOME should have been defined,
#       and ensure_node_is_on_path should have been executed.
#
# @param string   component directory
process_component_discovery_shared_libs() {
  component_dir="${1}"

  # make sure $ZWE_DISCOVERY_SHARED_LIBS exists
  mkdir -p "${ZWE_DISCOVERY_SHARED_LIBS}"

  all_succeed=true
  iterator_index=0
  plugin_name=
  discovery_shared_libs_workspace_path=
  discovery_shared_libs_path=$(read_component_manifest "${component_dir}" ".discoverySharedLibs[${iterator_index}]" 2>/dev/null)
  while [ -n "${discovery_shared_libs_path}" ]; do
    cd "${component_dir}"

    if [ -z "${plugin_name}" ]; then
      # prepare plugin directory
      plugin_name=$(read_component_manifest "${component_dir}" ".name" 2>/dev/null)
      if [ -z "${plugin_name}" ]; then
        print_error "Cannot read name from the plugin ${component_dir}"
        all_succeed=false
        break
      fi
      discovery_shared_libs_workspace_path="${ZWE_DISCOVERY_SHARED_LIBS}/${plugin_name}"
      mkdir -p "${discovery_shared_libs_workspace_path}"
    fi

    # copy manifest to workspace
    component_manifest=$(get_component_manifest "${component_dir}")
    if [ ! -z "${component_manifest}" -a -f "${component_manifest}" ]; then
      cp "${component_manifest}" "${discovery_shared_libs_workspace_path}"
    fi

    # copy libraries to workspace/discovery/sharedLibs/<plugin-id>
    # Due to limitation of how Java loading shared libraries, all jars are copied to plugin root directly.
    if [ -f "${discovery_shared_libs_path}" ]; then
      cp "${discovery_shared_libs_path}" "${discovery_shared_libs_workspace_path}"
    elif [ -d "${discovery_shared_libs_path}" ]; then
      find "${discovery_shared_libs_path}" -type f | xargs -I{} cp {} "${discovery_shared_libs_workspace_path}"
    else
      print_error "Discovery shared libs directory ${discovery_shared_libs_path} is not accessible"
      all_succeed=false
      break
    fi

    iterator_index=`expr $iterator_index + 1`
    discovery_shared_libs_path=$(read_component_manifest "${component_dir}" ".discoverySharedLibs[${iterator_index}]" 2>/dev/null)
  done

  if [ "${all_succeed}" = "true" ]; then
    return 0
  else
    # error message should have be echoed before this
    return 1
  fi
}

###############################
# Call API Catalog to refresh static registration
#
# @param string   API Catalog hostname
# @param string   API Catalog port
# @param string   Path to Authentication private key
# @param string   Path to Authentication certificate
# @param string   Path to Certificate Authority certificate
refresh_static_registration() {
  apicatalog_host="${1:-${ZWE_GATEWAY_HOST:-${ZWE_haInstance_hostname:-localhost}}}"
  apicatalog_port="${2:-${ZWE_components_api_catalog_port}}"
  auth_key="${3:-${ZWE_zowe_certificate_pem_key}}"
  auth_cert="${4:-${ZWE_zowe_certificate_pem_certificate}}"
  ca_cert="${5:-${ZWE_zowe_certificate_pem_certificateAuthorities}}"

  require_node

  utils_dir="${ZWE_zowe_runtimeDirectory}/bin/utils"

  print_trace "- calling API Catalog /static-api/refresh to refresh static registrations"
  result=$("${NODE_HOME}/bin/node" \
            "${utils_dir}/curl.js" \
            "https://${apicatalog_host}:${apicatalog_port}/apicatalog/static-api/refresh" \
            -X POST \
            --key "${auth_key}" \
            --cert "${auth_cert}" \
            --cacert "${ca_cert}")
  code=$?
  if [ ${code} -eq 0 ]; then
    print_trace "  * Exit code: ${code}"
    print_trace "  * Output:"
    if [ -n "${result}" ]; then
      print_trace "$(padding_left "${result}" "    ")"
    fi
  else
    print_error "  * Exit code: ${code}"
    print_error "  * Output:"
    if [ -n "${result}" ]; then
      print_error "$(padding_left "${result}" "    ")"
    fi
    print_error_and_exit "Error ZWEL0142E: Failed to refresh APIML static registrations." "" 142
  fi

  return ${code}
}
