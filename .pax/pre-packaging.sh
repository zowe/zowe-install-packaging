#!/bin/sh -e
set -x

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018, 2019
################################################################################

FUNC=[CreatePax][pre-packaging]
CURRENT_PWD=$(pwd)
SCRIPT_NAME=$(basename "$0")
ZOWE_VERSION=$(cat content/version)

if [ -z "$ZOWE_VERSION" ]; then
  echo "$SCRIPT_NAME ZOWE_VERSION environment variable is missing"
  exit 1
else
  echo "$SCRIPT_NAME working on Zowe v${ZOWE_VERSION} ..."
  # remove the version file
  rm content/version
fi

# Create mediation PAX
cd mediation
pax -x os390 -w -f ../content/zowe-$ZOWE_VERSION/files/api-mediation-package-0.8.4.pax *
cd ..

# Cleanup working files
rm -rf mediation
rm -f mediation.tar

# extract zss.pax
mkdir -p content/zowe-$ZOWE_VERSION/files/zss
cd content/zowe-$ZOWE_VERSION/files/zss
pax -r -px -f ../zss.pax
rm ../zss.pax
[ -f "SAMPLIB/ZWESIS01" ] && rm SAMPLIB/ZWESIS01
[ -f "SAMPLIB/ZWESISMS" ] && rm SAMPLIB/ZWESISMS
cd "$CURRENT_PWD"

# FIXME: smpe doesn't need this config file? or should be somewhere else?
rm content/zowe-$ZOWE_VERSION/install/zowe-install.yaml

# display extracted files
echo "$FUNC content of $PWD...."
find . -print

echo "$SCRIPT_NAME change scripts to be executable ..."
chmod +x content/zowe-$ZOWE_VERSION/scripts/*.sh
chmod +x content/zowe-$ZOWE_VERSION/scripts/opercmd
chmod +x content/zowe-$ZOWE_VERSION/scripts/ocopyshr.clist
chmod +x content/zowe-$ZOWE_VERSION/install/*.sh
