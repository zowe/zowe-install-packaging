################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018
################################################################################

set -e
# We are in the /scripts folder beneath a Zowe install
# If we are run directly from the shell we need to switch up a directory to 
# be able to work with zlux-example-server and explorer-server
# If we are run from the zowe-install.sh script then we need to switch into the
# ZOWE_ROOT_DIR as this will be where the install has put us, so we can work from there
# cd to the top level folder as this is where the zlux-example-server and the explorer-server are
if [[ $ZOWE_ROOT_DIR == "" ]]
    then
        cd ..
    else
        cd $ZOWE_ROOT_DIR
fi

# This is from the zLUX install

if extattr ./zlux-example-server/bin/zssServer | grep "APF authorized = NO"; then
  echo "zssServer does not have the proper extattr values"
  echo "   Please run extattr +a $PWD/zlux-example-server/bin/zssServer"
  exit 1
fi

#
# Permission fix for zLux Server
# 
chmod -R ug+w ./zlux-example-server/deploy/site
chmod -R ug+w ./zlux-example-server/deploy/instance

# This is from the explorer-server install
cd explorer-server

#echo "Creating symlink from the explorer server for its bootstrap properties to where z/OSMF is"
chgrp -R IZUADMIN wlp
chgrp IZUADMIN $PWD
chmod -R g+w wlp
mkdir -p ./wlp/usr/servers/Atlas/resources
chmod g+w ./wlp/usr/servers/Atlas/resources
# Added to pre-create liberty directories which are normally created at first startup
mkdir -p ./wlp/usr/servers/.pid
chmod ug+rwx ./wlp/usr/servers/.pid
mkdir -p ./wlp/usr/servers/Atlas/workarea/org.eclipse.osgi/169/0/.cp/lib
chmod -R +X ./wlp/usr/servers/Atlas/workarea

# Permission fixing for the explorer server
# These must be done before the symlinks are changed, as otherwise it tries to change the actual
# target of the symlink which lies in z/OSMF and the permission fails and aborts the install
chmod a+rw ./
chmod a+rx ./
chmod -R 755  ./
chmod a+w ./wlp/usr/servers
chmod a+w ./wlp/usr/servers/.classCache
chmod a+w ./wlp/usr/servers/.classCache/javasharedresources/*
chmod a+w ./wlp/usr/servers/.classCache/javasharedresources
chmod -R a+rwx ./wlp/usr/servers/Atlas

ln -s %zosmfpath%bootstrap.properties ./wlp/usr/servers/Atlas/bootstrap.properties
# "Creating symlink from the explorer server to z/OSMF for sharing the ltpa.keys file and sharing authentication credentials"
ln -s %zosmfpath%jvm.security.override.properties ./wlp/usr/servers/Atlas/jvm.security.override.properties

mkdir -p ./wlp/usr/servers/Atlas/resources/security
chmod a+w ./wlp/usr/servers/Atlas/resources/security
ln -s %zosmfpath%resources/security/ltpa.keys ./wlp/usr/servers/Atlas/resources/security/ltpa.keys

