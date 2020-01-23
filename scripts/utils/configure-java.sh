#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2020
################################################################################

#Make sure Java is available on the PATH
if [[ ":$PATH:" != *":$JAVA_HOME/bin:"* ]];
then
  echo "Appending JAVA_HOME/bin to the PATH..."
  export PATH=$PATH:$JAVA_HOME/bin
fi