#!/bin/bash

# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.

# - Build docker image
#
# This script takes 2 parameters:
# 1. tag identifier
# 2. zowe build url
#
# Examples:
# ./build.sh amd64
# ./build.sh amd64 latest
# ./build.sh amd64 https://zowe.jfrog.io/zowe/libs-snapshot-local/org/zowe/1.17.0-STAGING/zowe-1.17.0-staging-1052-20201017043641.pax

mkdir -p utils
cp -r ../utils/* ./utils
if [ "$#" -lt 1 ]
then
  echo "Usage: $0 <build name> [pax location]"
  exit 1
fi
   
if [ "$1" = "" ]; then
  docker build -f Dockerfile --no-cache -t ompzowe/server-bundle:testing$1 .
else
  docker build -f Dockerfile --no-cache --build-arg ZOWE_BUILD=$2 -t ompzowe/server-bundle:testing$1 .
fi
