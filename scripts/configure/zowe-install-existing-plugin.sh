#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Broadcom 2019
################################################################################

# Requires passed in:
# ZOWE_ROOT_DIR - install root directory
# PLUGIN_ID - id of the plugin - e.g. "org.zowe.zlux.auth.apiml"
# PLUGIN_DIR - absolute path to the directory with the plugin

ZOWE_ROOT_DIR=$1
PLUGIN_ID=$2
PLUGIN_DIR=$3

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 ZOWE_INSTALL_ROOT_DIRECTORY PLUGIN_ID PLUGIN_DIR\ne.g. install-existing-plugin.sh \"~/zowe\" \"org.zowe.plugin.example\" \"~/zowe/myplugins/example\"" >&2
  exit 1
fi
if ! [ -d "$1" ]; then
  echo "$1 not a directory, please provide the full path to the root installation directory of Zowe" >&2
  exit 1
fi
if ! [ -d "$3" ]; then
  echo "$3 not a directory, please provide the full path to the directory with the plugin" >&2
  exit 1
fi

zluxserverdirectory='zlux-app-server'

chmod -R u+w $ZOWE_ROOT_DIR/$zluxserverdirectory/plugins/

cat <<EOF >$ZOWE_ROOT_DIR/$zluxserverdirectory/plugins/$PLUGIN_ID.json
{
    "identifier": "$PLUGIN_ID",
    "pluginLocation": "$PLUGIN_DIR"
}
EOF
