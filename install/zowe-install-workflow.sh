#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018, 2020
################################################################################

# copy generated workflows to zowe/workflows USS directory

mkdir "$ZOWE_ROOT_DIR/workflows"
TARGET_DIR= "$ZOWE_ROOT_DIR/workflows"
WORKFLOWS_DIR="/workflows"

# look for empty dir
if [ "$(ls -A $WORKFLOWS_DIR)" ]; then
     cp "$WORKFLOWS_DIR/" "$TARGET_DIR"
else
    echo "$WORKFLOWS_DIR is Empty"
fi
