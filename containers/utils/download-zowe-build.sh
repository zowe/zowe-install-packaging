#!/bin/bash

# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.

ZOWE_BUILD=$1
ZOWE_TARGET_NAME=zowe.pax

# this is workdir expected
cd /home/zowe

if [ "$ZOWE_BUILD" = "latest" ]; then
  echo "Downloading most recent release ..."
  apt-get update && apt-get install -y wget --no-install-recommends
  wget -q "https://zowe.jfrog.io/zowe/libs-release-local/org/zowe/[RELEASE]/zowe-[RELEASE].pax" -O "$ZOWE_TARGET_NAME"
  apt-get purge -y wget
elif [[ $ZOWE_BUILD = https://* ]]; then
  echo "Downloading $ZOWE_BUILD ..."
  apt-get update && apt-get install -y wget --no-install-recommends
  wget -q "$ZOWE_BUILD" -O "$ZOWE_TARGET_NAME"
  apt-get purge -y wget
else
  echo "Try to use local Zowe build (zowe.pax)"
fi

if [ ! -f "$ZOWE_TARGET_NAME" ]; then
  echo "Error: failed to find Zowe build ${ZOWE_BUILD}."
  exit 1
fi

echo "Files we have:"
ls -la
exit 0
