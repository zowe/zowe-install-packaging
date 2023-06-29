#!/bin/bash

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.
################################################################################

################################################################################
# prepare docker build context
#
# This script will be executed with 2 parameters:
# - linux-distro
# - cpu-arch

###############################
# check parameters
linux_distro=$1
cpu_arch=$2
if [ -z "${linux_distro}" ]; then
  echo "Error: linux-distro parameter is missing."
  exit 1
fi
if [ -z "${cpu_arch}" ]; then
  echo "Error: cpu-arch parameter is missing."
  exit 1
fi

###############################
# copy Dockerfile
mkdir -p "${linux_distro}/amd64"
mkdir -p "${linux_distro}/s390x"
cp "${linux_distro}/Dockerfile.nodejava.amd64" "${linux_distro}/amd64/Dockerfile"
cp "${linux_distro}/Dockerfile.nodejava.s390x" "${linux_distro}/s390x/Dockerfile"

###############################
# done
echo ">>>>> all done"
