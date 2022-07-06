#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2022
################################################################################

# color encoding
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# init
CURRENT_BRANCH_NEW=$(echo "$CURRENT_BRANCH" | tr '[:upper:]' '[:lower:]' | sed "s#\/#-#g")

TOTAL_CHECK=3
if [[ "$MATRIX_TEST" == *"install-ext"* ]]; then
    ((TOTAL_CHECK++))
fi