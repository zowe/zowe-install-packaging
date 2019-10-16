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

# if NODE_HOME set by user, don't override
if [[ ! -f $NODE_HOME/"./bin/node" ]]
then
  export NODE_HOME=$ZOWE_NODE_HOME
fi

#Make sure Node is available on the PATH
if [[ ":$PATH:" != *":$NODE_HOME/bin:"* ]];
then
  echo "Appending NODE_HOME/bin to the PATH..."
  export PATH=$PATH:$NODE_HOME/bin
fi