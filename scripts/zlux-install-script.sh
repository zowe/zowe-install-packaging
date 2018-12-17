################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018
################################################################################

#This file is for installing the pax file of zlux. It lives here so it is covered by source control. It is not called from this location
#!/bin/sh

cd $ZOWE_ROOT_DIR
umask 0002
echo "Unpax $INSTALL_DIR/files/ZLUX.pax " >> $LOG_FILE
pax -r -px -f $INSTALL_DIR/files/ZLUX.pax

chmod -R a-w tn3270-ng2/ vt-ng2/ zlux-app-manager/ zlux-example-server/ zlux-ng2/ zlux-proxy-server/ zlux-shared/ zos-subsystems/ 2>/dev/null
chmod ug+w zlux-example-server/
mkdir zlux-example-server/log
chmod ug-w zlux-example-server/

cd zlux-example-server
chmod -R a-w bin/ build/ config/ deploy/product/ js/ plugins/ .gitattributes .gitignore README.md 2>/dev/null
chmod ug+w bin/zssServer

# Open the permission so that a user other than the one who does the install can start the nodeServer
# and create logs
chmod a+w log

cd $INSTALL_DIR
