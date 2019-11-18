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

SCRIPT_NAME=$(basename "$0")

if [ -z "$ZOWE_VERSION" ]; then
  echo "$SCRIPT_NAME ZOWE_VERSION environment variable is missing"
  exit 1
else
  echo "$SCRIPT_NAME working on Zowe v${ZOWE_VERSION} ..."
fi

# Create mediation PAX
cd mediation
pax -x os390 -w -f ../content/zowe-$ZOWE_VERSION/files/api-mediation-package-0.8.4.pax *
cd ..

# Cleanup working files
rm -rf mediation

echo "$SCRIPT_NAME change scripts to be executable ..."
chmod +x content/zowe-$ZOWE_VERSION/bin/*.sh
chmod +x content/zowe-$ZOWE_VERSION/scripts/*.sh
chmod +x content/zowe-$ZOWE_VERSION/scripts/opercmd
chmod +x content/zowe-$ZOWE_VERSION/scripts/ocopyshr.clist
chmod +x content/zowe-$ZOWE_VERSION/install/*.sh

# prepare for SMPE
echo "$SCRIPT_NAME smpe is not part of zowe.pax, moving out ..."
mv content/smpe .
