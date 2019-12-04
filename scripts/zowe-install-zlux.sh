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

#This file is for installing the pax file of zlux. It lives here so it is covered by source control. It is not called from this location

#********************************************************************
# Expected globals:
# $ZOWE_APIM_ENABLE_SSO
# $CONFIG_DIR
# $ZOWE_ROOT_DIR
# $TEMP_DIR



umask 0002
APP_SERVER_COMPONENT_DIR=${ZOWE_ROOT_DIR}/components/app-server
mkdir -p ${APP_SERVER_COMPONENT_DIR}
cd ${APP_SERVER_COMPONENT_DIR}
mkdir bin
mkdir share
cd share
echo "Unpax $INSTALL_DIR/files/zlux/zlux-core.pax " >> $LOG_FILE
pax -r -px -f $INSTALL_DIR/files/zlux/zlux-core.pax

for paxfile in ${INSTALL_DIR}/files/zlux/*.pax
do
  if [[ $paxfile != "${INSTALL_DIR}/files/zlux/zlux-core.pax" ]]
  then
    filename=$(basename $paxfile)
    pluginName="${filename%.*}"
    mkdir $pluginName && cd $pluginName
    echo "Unpax ${paxfile} " >> $LOG_FILE
    pax -r -px -f ${paxfile}
    cd ..
  fi
done

mkdir -p zlux-app-server/defaults/ZLUX/pluginStorage/org.zowe.zlux.ng2desktop/ui/launchbar/plugins
cp -f ${INSTALL_DIR}/files/zlux/config/pinnedPlugins.json zlux-app-server/defaults/ZLUX/pluginStorage/org.zowe.zlux.ng2desktop/ui/launchbar/plugins/
cp -f ${INSTALL_DIR}/files/zlux/config/zluxserver.json zlux-app-server/defaults/serverConfig/server.json
cp -f ${INSTALL_DIR}/files/zlux/config/plugins/* zlux-app-server/defaults/plugins

echo "Unpax zssServer " >> $LOG_FILE
cd zlux-app-server/bin
pax -r -px -f $INSTALL_DIR/files/zss.pax zssServer
extattr +p zssServer
cd ../..

chmod -R a-w tn3270-ng2/ vt-ng2/ zlux-app-manager/ zlux-app-server/ zlux-ng2/ zlux-server-framework/ zlux-shared/ 2>/dev/null
chmod ug-w zlux-app-server/

cd zlux-app-server
if [[ $ZOWE_APIM_ENABLE_SSO == "true" ]]; then
  chmod -R u+w defaults/
  # Add APIML authentication plugin to zLUX
  . ${APP_SERVER_COMPONENT_DIR}/zlux-app-server/bin/install-app.sh $ZOWE_ROOT_DIR/components/api-mediation/apiml-auth 
#  . $CONFIG_DIR/zowe-install-existing-plugin.sh $ZOWE_ROOT_DIR "org.zowe.zlux.auth.apiml" $ZOWE_ROOT_DIR/components/api-mediation/apiml-auth
  # Activate the plugin
  _JSON='"apiml": { "plugins": ["org.zowe.zlux.auth.apiml"] }'
  ZLUX_SERVER_CONFIG_PATH=${APP_SERVER_COMPONENT_DIR}/zlux-app-server/defaults/serverConfig
  sed 's/"zss": {/'"${_JSON}"', "zss": {/g' ${ZLUX_SERVER_CONFIG_PATH}/server.json > ${TEMP_DIR}/transform1.json
  cp ${TEMP_DIR}/transform1.json ${ZLUX_SERVER_CONFIG_PATH}/server.json
  rm ${TEMP_DIR}/transform1.json
fi
chmod -R a-w bin/ build/ defaults/ js/ plugins/ .gitattributes .gitignore README.md 2>/dev/null
cp bin/start.sh bin/configure.sh ${APP_SERVER_COMPONENT_DIR}/bin

cd $INSTALL_DIR
