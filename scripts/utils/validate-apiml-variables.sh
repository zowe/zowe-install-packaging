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

# - KEYSTORE - The keystore to use for SSL certificates
# - KEYSTORE_PASSWORD - The password to access the keystore supplied by KEYSTORE
# - KEY_ALIAS - The alias of the key within the keystore

. ${ROOT_DIR}/bin/utils/utils.sh
validate_variables_are_set "KEYSTORE KEYSTORE_PASSWORD KEY_ALIAS"

validate_directory_is_writable ${STATIC_DEF_CONFIG_DIR}

validate_directory_is_writable ${ZWE_GATEWAY_SHARED_LIBS}
