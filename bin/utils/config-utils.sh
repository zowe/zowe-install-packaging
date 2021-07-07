#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2021
################################################################################

########################################################
# convert components YAML manifest to JSON format
convert_all_component_manifests_to_json() {
  print_formatted_info "ZWELS" "config-utils.sh,convert_all_component_manifests_to_json:${LINENO}" "prepare component manifest ..."
  for component_id in $(echo "${LAUNCH_COMPONENTS}" | sed "s/,/ /g")
  do
    component_dir=$(find_component_directory "${component_id}")
    if [ -n "${component_dir}" ]; then
      print_formatted_debug "ZWELS" "config-utils.sh,convert_all_component_manifests_to_json:${LINENO}" "- ${component_id}"
      component_manifest_conversion_output=$(convert_component_manifest "${component_dir}" 2>&1)
      if [ "$?" != "0" ]; then
        print_formatted_warn "ZWELS" "config-utils.sh,convert_all_component_manifests_to_json:${LINENO}" "manifest file of ${component_id} is invalid"
        print_formatted_error "ZWELS" "config-utils.sh,convert_all_component_manifests_to_json:${LINENO}" "Prepare ${component_id} manifest failed: ${component_manifest_conversion_output}"
      fi
    fi
  done
  print_formatted_debug "ZWELS" "config-utils.sh,convert_all_component_manifests_to_json:${LINENO}" "component manifests prepared"
}

###############################
# Convert instance.env to zowe.yaml file
convert_instance_env_to_yaml() {
  instance_env=$1
  zowe_yaml=$2

  # we need node for following commands
  ensure_node_is_on_path 1>/dev/null 2>&1

  if [ -z "${zowe_yaml}" ]; then
    node "${ROOT_DIR}/bin/utils/config-converter/src/cli.js" env yaml "${instance_env}"
  else
    node "${ROOT_DIR}/bin/utils/config-converter/src/cli.js" env yaml "${instance_env}" -o "${zowe_yaml}"

    # convert encoding to IBM-1047
    if [ "$(is_on_zos)" = "true" ]; then
      # most likely it's tagged
      config_encoding=$(detect_file_encoding "${zowe_yaml}" "zowe:")
      if [ -n "${config_encoding}" ]; then
        # any cases we cannot find encoding?
        if [ "${config_encoding}" != "IBM-1047" ]; then
          iconv -f "${config_encoding}" -t "IBM-1047" "${zowe_yaml}" > "${zowe_yaml}.tmp"
          mv "${zowe_yaml}.tmp" "${zowe_yaml}"
        fi
        chtag -r "${zowe_yaml}" 2>/dev/null
      fi
    fi

    chmod 640 "${zowe_yaml}"
  fi
}

###############################
# Check encoding of a file and convert to IBM-1047 if needed.
#
# Note: usually this is required if the file is supposed to be shell script,
#       which requires to be IBM-1047 encoding.
#
# @param string    file to check and convert
zos_convert_env_dir_file_encoding() {
  file=$1

  encoding=$(zos_get_file_tag_encoding "$file")
  echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>BEFORE ${file} encoding is ${encoding}"
  cat "$file"
  echo "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  if [ "${encoding}" != "UNTAGGED" -a "${encoding}" != "IBM-1047" ]; then
    tmpfile="${ZWELS_INSTANCE_ENV_DIR}/t"
    rm -f "${tmpfile}"
    iconv -f "${encoding}" -t "IBM-1047" "${file}" > "${tmpfile}"
    mv "${tmpfile}" "${file}"
    chmod 640 "${file}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>AFTER ${file}"
    ls -laT "${file}"
    cat "$file"
    echo "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  fi
}

###############################
# Prepare configuration for current HA instance, and generate backward
# compatible instance.env files from zowe.yaml.
#
# @param string   HA instance ID
generate_instance_env_from_yaml_config() {
  ha_instance=$1

  if [ "${ZWELS_CONFIG_LOAD_METHOD}" != "zowe.yaml" ]; then
    # still using instance.env, nothing to do
    return 0
  fi

  # we need node for following commands
  ensure_node_is_on_path 1>/dev/null 2>&1

  # delete old files to avoid potential issues
  find "${ZWELS_INSTANCE_ENV_DIR}" -type f -name ".*-${ha_instance}.env" | xargs rm -f
  find "${ZWELS_INSTANCE_ENV_DIR}" -type f -name ".*-${ha_instance}.json" | xargs rm -f
  find "${ZWELS_INSTANCE_ENV_DIR}" -type f -name ".zowe.yaml" | xargs rm -f

  # prepare .zowe.json and .zowe-<ha-id>.json
  node "${ROOT_DIR}/bin/utils/config-converter/src/cli.js" yaml convert --wd "${ZWELS_INSTANCE_ENV_DIR}" --ha "${ha_instance}" "${INSTANCE_DIR}/zowe.yaml"
  if [ ! -f "${ZWELS_INSTANCE_ENV_DIR}/.zowe.json" ]; then
    exit_with_error "failed to translate <instance-dir>/zowe.yaml" "config-utils.sh,generate_instance_env_from_yaml_config:${LINENO}"
  fi

  # convert YAML configurations to backward compatible .instance-<ha-id>.env files
  node "${ROOT_DIR}/bin/utils/config-converter/src/cli.js" yaml env --wd "${ZWELS_INSTANCE_ENV_DIR}" --ha "${ha_instance}"

  # this is not needed after sourced bin/internal/zowe-set-env.sh
  # fix files encoding
  # node.js may create instance.env with ISO8859-1, need to convert to IBM-1047 to allow shell to read
  # if [ "$(is_on_zos)" = "true" ]; then
  #   for one in $(find "${ZWELS_INSTANCE_ENV_DIR}" -type f -name '.instance-*.env') ; do
  #     zos_convert_env_dir_file_encoding "${one}"
  #   done
  # fi
}
