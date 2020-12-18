#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2020
################################################################################

#********************************************************************
# Expected globals:
# $ZOWE_ROOT_DIR
# $INSTALL_DIR
# $LOG_FILE

echo "<zowe-install-components.sh>" >> $LOG_FILE

component_list="jobs-api files-api api-catalog discovery gateway caching-service common-lib"
for component_id in ${component_list}; do
  cd ${INSTALL_DIR}
  component_zip=$PWD/$(ls -t ./files/${component_id}*.zip | head -1)
  component_dir="${ZOWE_ROOT_DIR}/components/${component_id}"
  
  echo "  Installing ${component_zip} into ${component_zip}" >> $LOG_FILE
  mkdir -p "${component_dir}"
  cd "${component_dir}"
  jar -xf "${component_zip}"
  ${INSTALL_DIR}/scripts/tag-files.sh "${component_dir}" 1>/dev/null
done

echo "</zowe-install-components.sh>" >> $LOG_FILE
