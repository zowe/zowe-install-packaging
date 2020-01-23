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

#Make sure Node is available on the PATH
if [[ ":$PATH:" != *":$NODE_HOME/bin:"* ]];
then
  echo "Appending NODE_HOME/bin to the PATH..."
  export PATH=$PATH:$NODE_HOME/bin
fi