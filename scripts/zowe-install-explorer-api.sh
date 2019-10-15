#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018, 2019
################################################################################

#********************************************************************
# Expected globals:
# $ZOWE_ROOT_DIR
# $INSTALL_DIR
# $LOG_FILE

echo "<zowe-explorer-api-install.sh>" >> $LOG_FILE


EXPLORER_API_LIST="jobs-api data-sets-api"
for COMPONENT_ID in $EXPLORER_API_LIST; do
  cd $INSTALL_DIR
  EXPLORER_API_JAR=$PWD/$(ls -t ./files/${COMPONENT_ID}-server-*.jar | head -1)
  if [ ! -f $EXPLORER_API_JAR ]; then
    echo "  Error: Explorer ${COMPONENT_ID} (${COMPONENT_ID}-server-*.jar) missing"
    echo "  Installation terminated"
    exit 0
  fi

   #TODO - rename the data-set jar and api list to match the compCOMPONENT_IDnt id
  if [ "$COMPONENT_ID" = "data-sets-api" ]; then
    COMPONENT_ID=files-api
  fi

  EXPLORER_API_START_SCRIPT=$PWD/files/scripts/${COMPONENT_ID}-start.sh
  CONFIGURE_SCRIPT=$PWD/files/scripts/${COMPONENT_ID}-configure.sh
  VALIDATE_SCRIPT=$PWD/files/scripts/${COMPONENT_ID}-validate.sh

  if [ ! -f $EXPLORER_API_START_SCRIPT ]; then
    echo "  Error: Explorer ${COMPONENT_ID} api start script (${COMPONENT_ID}-start.sh) missing"
    echo "  Installation terminated"
    exit 0
  fi

  echo "  Installing Explorer ${COMPONENT_ID} API into ${ZOWE_ROOT_DIR}/components/${COMPONENT_ID} ..."  >> $LOG_FILE
  umask 0002
  mkdir -p "${ZOWE_ROOT_DIR}/components/${COMPONENT_ID}/bin"
  # copy jar
  cd "${ZOWE_ROOT_DIR}/components/${COMPONENT_ID}/bin"
  echo "  Copy ${EXPLORER_API_JAR} into ${PWD}" >> $LOG_FILE
  cp $EXPLORER_API_JAR .

  EXPLORER_API_JAR=$(ls -d -t ${ZOWE_ROOT_DIR}/components/${COMPONENT_ID}/bin/*-api-server-*.jar | head -1)
  chmod a+rx $EXPLORER_API_JAR
  # copy start script
  JAR_NAME=$(basename "$EXPLORER_API_JAR")
  sed -e "s#{{jar_path}}#\${ROOT_DIR}/components/${COMPONENT_ID}/bin/${JAR_NAME}#" \
     $EXPLORER_API_START_SCRIPT > "start.sh"  

  if [[ -f ${CONFIGURE_SCRIPT} ]]
  then
    cp ${CONFIGURE_SCRIPT} configure.sh
  fi

  if [[ -f ${VALIDATE_SCRIPT} ]]
  then
    cp ${VALIDATE_SCRIPT} validate.sh
  fi
  chmod -R 755 "${ZOWE_ROOT_DIR}/components/${COMPONENT_ID}/bin"
done

echo "</zowe-explorer-api-install.sh>" >> $LOG_FILE
