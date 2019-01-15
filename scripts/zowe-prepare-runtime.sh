#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018, 2019
################################################################################

zluxserverdirectory='zlux-app-server'

echo "Preparing folder permission for zLux plugins foder..." >> $LOG_FILE
chmod -R u+w $ZOWE_ROOT_DIR/$zluxserverdirectory/plugins/
