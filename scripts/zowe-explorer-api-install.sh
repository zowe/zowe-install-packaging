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


EXPLORER_API_LIST="jobs data-sets"
for one in $EXPLORER_API_LIST; do
  cd $INSTALL_DIR
  EXPLORER_API_JAR=$PWD/$(ls -t ./files/${one}-api-server-*.jar | head -1)
  if [ ! -f $EXPLORER_API_JAR ]; then
    echo "  Error: Explorer ${one} api (${one}-api-server-*.jar) missing"
    echo "  Installation terminated"
    exit 0
  fi

   #TODO - rename the data-set jar and api list to match the component id
  if [ "$one" = "data-sets" ]; then
    one=files
  fi

  EXPLORER_API_START_SCRIPT=$PWD/$(ls -t ./files/scripts/${one}-start.sh | head -1)
  if [ ! -f $EXPLORER_API_START_SCRIPT ]; then
    echo "  Error: Explorer ${one} api start script (${one}-start.sh) missing"
    echo "  Installation terminated"
    exit 0
  fi

  EXPLORER_INSTALL_FOLDER="${one}-api"
  echo "  Installing Explorer ${one} API into ${ZOWE_ROOT_DIR}/${EXPLORER_INSTALL_FOLDER} ..."  >> $LOG_FILE
  umask 0002
  mkdir -p "${ZOWE_ROOT_DIR}/components/${EXPLORER_INSTALL_FOLDER}/bin"
  # copy jar
  cd "${ZOWE_ROOT_DIR}/components/${EXPLORER_INSTALL_FOLDER}/bin"
  echo "  Copy ${EXPLORER_API_JAR} into ${PWD}" >> $LOG_FILE
  cp $EXPLORER_API_JAR .

  EXPLORER_API_JAR=$(ls -d -t ${ZOWE_ROOT_DIR}/components/${EXPLORER_INSTALL_FOLDER}/bin/*-api-server-*.jar | head -1)
  chmod a+rx $EXPLORER_API_JAR
  # copy start script
  sed -e "s#{{jar_path}}#${EXPLORER_API_JAR}#" \
     $EXPLORER_API_START_SCRIPT > "start.sh"  

  CONFIGURE_SCRIPT=$PWD/$(ls -t ./files/scripts/${one}-configure.sh | head -1)
  if [[ -f ${CONFIGURE_SCRIPT} ]]
  then
    cp ${CONFIGURE_SCRIPT} configure.sh
  fi

  VALIDATE_SCRIPT=$PWD/$(ls -t ./files/scripts/${one}-validate.sh | head -1)
  if [[ -f ${VALIDATE_SCRIPT} ]]
  then
    cp ${VALIDATE_SCRIPT} validate.sh
  fi

  chmod a+x *.sh
  chmod 755 "${ZOWE_ROOT_DIR}/components/${EXPLORER_INSTALL_FOLDER}/bin"
done

echo "</zowe-explorer-api-install.sh>" >> $LOG_FILE
