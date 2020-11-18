#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018, 2020
################################################################################

#********************************************************************
# Expected globals:
# $ZOWE_ROOT_DIR
# $INSTALL_DIR
# $LOG_FILE

echo "<zowe-explorer-ui-install.sh>" >> $LOG_FILE

umask 0002
ui_components="explorer-ui-server explorer-jes explorer-mvs explorer-uss"
for component_id in ${ui_components}; do
  cd ${INSTALL_DIR}
  component_pax=$PWD/$(ls -t ./files/${component_id}-*.pax | head -1)
  if [ ! -f ${component_pax} ]; then
    echo "  ${component_id} Explorer UI (${component_id}-*.pax) missing"
    echo "  Installation terminated"
    exit 0
  fi

  # NOTICE: zowe-install-iframe-plugin.sh will try to automatically create install folder based on plugin name
  component_directory="${ZOWE_ROOT_DIR}/components/${component_id}"
  echo "  Installing Explorer UI ${component_id} into ${component_directory} ..."  >> $LOG_FILE
  
  mkdir -p "${component_directory}"
  echo "  Unpax of ${component_pax} into ${PWD}" >> $LOG_FILE
  pax -rf ${component_pax} -ppx

  # TODO - do we need this section. Can we unify it, or derive this from the manifest?
  if [[ "${component_id}" == "explorer-ui-server " ]]; then
    chmod -R 755 "${component_directory}"
  elif
    chmod -R 755 "${component_directory}/bin"
  fi
done
echo "</zowe-explorer-ui-install.sh>" >> $LOG_FILE
