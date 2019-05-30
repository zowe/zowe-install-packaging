#!/bin/sh -e
set -x

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018
################################################################################

FUNC=[CreatePax][pre-packaging]
PWD=$(pwd)

if [ -z "$ZOWE_VERSION" ]; then
  echo "$FUNC ZOWE_VERSION environment variable is missing"
  exit 1
else
  echo "$FUNC working on Zowe v${ZOWE_VERSION} ..."
fi

# extract ASCII files
echo "$FUNC extracting ASCII files ...."
pax -r -x tar -o to=IBM-1047 -f ascii.tar
# copy to target folder
cp -R ascii/. content/zowe-$ZOWE_VERSION
# remove ascii files
rm ascii.tar
rm -fr ascii

# Extract mediation tar and go into the dir
pax -r -x tar -f api-mediation.tar
cd mediation

# Create mediation PAX
pax -x os390 -w -f ../content/zowe-$ZOWE_VERSION/files/api-mediation-package-0.8.4.pax *
cd ..

#Cleanup working files
rm -rf mediation
rm -f mediation.tar

# extract zss.pax
mkdir -p files/zss
cd files/zss
pax -r -px -f ../zss.pax
rm ../zss.pax
cd ../..

# display extracted files
echo "$FUNC content of $PWD...."
find . -print

echo "$FUNC change scripts to be executable..."
chmod +x content/zowe-$ZOWE_VERSION/scripts/*.sh
chmod +x content/zowe-$ZOWE_VERSION/scripts/opercmd
chmod +x content/zowe-$ZOWE_VERSION/scripts/ocopyshr.clist
chmod +x content/zowe-$ZOWE_VERSION/install/*.sh
