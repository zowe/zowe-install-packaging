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
#!/bin/sh


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
chmod -R a-w bin/ build/ config/ deploy/product/ js/ plugins/ .gitattributes .gitignore README.md 2>/dev/null
cp bin/start.sh bin/configure.sh ${APP_SERVER_COMPONENT_DIR}/bin


cd $INSTALL_DIR
