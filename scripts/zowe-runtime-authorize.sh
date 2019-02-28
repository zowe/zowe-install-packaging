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

set -e
# We are in the /scripts folder beneath a Zowe install
# If we are run directly from the shell we need to switch up a directory to 
# be able to work with zlux-app-server and explorer-server
# If we are run from the zowe-install.sh script then we need to switch into the
# ZOWE_ROOT_DIR as this will be where the install has put us, so we can work from there
# cd to the top level folder as this is where the zlux-app-server and the explorer-server are
if [[ $ZOWE_ROOT_DIR == "" ]]
    then
        cd ..
    else
        cd $ZOWE_ROOT_DIR
fi

# This is from the zLUX install

if extattr ./zlux-app-server/bin/zssServer | grep "Program controlled = NO"; then
  echo "zssServer does not have the proper extattr values"
  echo "   Please run extattr +p $PWD/zlux-app-server/bin/zssServer"
  exit 1
fi

#
# Permission fix for zLux Server.  The ZLUX server must have permission to write persistent data
# to ZFS.  We can't chown or chgrp as the user running the install doesn't have access rights to do this on 
# behalf of IZUSVR, so for now allow write permission for any
# 
chmod -R 770 zlux-app-server/deploy
chmod -R 550 zlux-app-server/deploy/product
# For Zowe to come up the ZOWESVR STC needs read access to ../deploy/instance/ZLUX/serverConfig/zluxServer.json
chmod -R g-w zlux-app-server/deploy/instance/ZLUX/serverConfig
chmod -R g-w zlux-app-server/deploy/site/ZLUX/serverConfig
if [ "$(ls -A zlux-app-server/deploy/instance/ZLUX/serverConfig)" ]; then
  chmod -R g-x zlux-app-server/deploy/instance/ZLUX/serverConfig/*
fi
if [ "$(ls -A zlux-app-server/deploy/site/ZLUX/serverConfig)" ]; then
  chmod -R g-x zlux-app-server/deploy/site/ZLUX/serverConfig/*
fi
# If this step fails it is because the user running this script is not part of the IZUADMIN group
# The reason they must be part of the group to do the chgrp is so that the zLux server that runs the ZOWESVR STC is able to access the group permission
# of the folders, which is IZUSVR : IZUADMIN
chgrp -R IZUADMIN zlux-app-server/deploy

# Ensure IZUSVR has UPDATE access to BPX.SERVER and BPX.DAEMON
# For zssServer to be able to operate correctly 
profile_refresh=0
for profile in SERVER DAEMON
do
    tsocmd rl facility "*" 2>/dev/null | grep BPX\.$profile >/dev/null
    if [[ $? -ne 0 ]]
    then
        # profile BPX\.$profile is not defined
        # Define the BPX facility
        tsocmd "RDEFINE FACILITY BPX.$profile UACC(NONE)" 2>/dev/null  1>/dev/null
        if [[ $? -ne 0 ]]
        then
          echo RDEFINE failed for BPX.$profile, please issue this command
          echo as a user with the required RACF privilege
          echo "    " "RDEFINE FACILITY BPX.$profile UACC(NONE)"
        fi 
        profile_refresh=1
    fi

    tsocmd rl facility bpx.$profile authuser 2>/dev/null |grep "IZUSVR *UPDATE" >/dev/null
    if [[ $? -ne 0 ]]
    then
        # User IZUSVR does not have UPDATE access to profile BPX\.$profile
        # Permit IZUSVR to update the BPX facilties 
        tsocmd "PERMIT BPX.$profile CLASS(FACILITY) ID(IZUSVR) ACCESS(UPDATE)" 2>/dev/null  1>/dev/null
        if [[ $? -ne 0 ]]
        then
          echo PERMIT failed for BPX.$profile, please issue this command
          echo as a user with the required RACF privilege
          echo "    " "PERMIT BPX.$profile CLASS(FACILITY) ID(IZUSVR) ACCESS(UPDATE)"
        fi 
        profile_refresh=1
    fi
done
if [[ profile_refresh -eq 1 ]]
then
     # Activate these changes 
    tsocmd "SETROPTS RACLIST(FACILITY) REFRESH " 2>/dev/null
    if [[ $? -ne 0 ]]
    then
          echo SETROPTS failed for class FACILITY, please issue this command
          echo as a user with the required RACF privilege
          echo "    " "SETROPTS RACLIST(FACILITY) REFRESH "
    fi 
fi