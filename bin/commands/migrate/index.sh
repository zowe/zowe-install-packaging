#!/bin/sh

instance_env=${ZWE_CLI_PARAMETER_INSTANCE_ENV}
zowe_yaml=${ZWE_CLI_PARAMETER_YAML}

function is_on_zos() {
  if [ `uname` = "OS/390" ]; then
    echo "true"
  fi
}

function ensure_zowe_yaml_encoding() {
  zowe_yaml=$1
  
  # convert encoding to IBM-1047
  if [ "$(is_on_zos)" = "true" ]; then
    # most likely it's tagged
    config_encoding=$(detect_file_encoding "${zowe_yaml}" "zowe:")
    if [ -n "${config_encoding}" ]; then
      # any cases we cannot find encoding?
      if [ "${config_encoding}" != "IBM-1047" ]; then
        iconv -f "${config_encoding}" -t "IBM-1047" "${zowe_yaml}" > "${zowe_yaml}.tmp"
        mv "${zowe_yaml}.tmp" "${zowe_yaml}"
        chmod 640 "${zowe_yaml}"
      fi
      chtag -r "${zowe_yaml}" 2>/dev/null
    fi
  fi
}

# we need node for following commands
ensure_node_is_on_path 1>/dev/null 2>&1
echo "Migrating from ${instance_env} to ${zowe_yaml}"
if [ -z "${zowe_yaml}" ]; then
   node "${ROOT_DIR}/config-converter/src/cli.js" env yaml "${instance_env}"
else
   node "${ROOT_DIR}/config-converter/src/cli.js" env yaml "${instance_env}" -o "${zowe_yaml}"

   ensure_zowe_yaml_encoding "${zowe_yaml}"

   chmod 640 "${zowe_yaml}"
fi


