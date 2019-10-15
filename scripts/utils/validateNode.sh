#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2019
################################################################################

# NODE_BIN Should exist and be on path
# TODO: add version check same as JAVA, officially we support NODE version 6
if [ ! -z "$NODE_HOME" ]; then
  NODE_BIN=${NODE_HOME}/bin/node
else
  . ${ROOT_DIR}/scripts/utils/error.sh "NODE_HOME is empty"
fi