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
if [[ -z "${KEYSTORE}" ]]
then 
    . ${ZOWE_ROOT_DIR}/scripts/utils/error.sh "KEYSTORE is empty"
fi
if [[ -z "${KEYSTORE_PASSWORD}" ]]
then 
    . ${ZOWE_ROOT_DIR}/scripts/utils/error.sh "KEYSTORE_PASSWORD is empty"
fi
if [[ -z "${KEY_ALIAS}" ]]
then 
    . ${ZOWE_ROOT_DIR}/scripts/utils/error.sh "KEY_ALIAS is empty"
fi

# - STATIC_DEF_CONFIG_DIR - Should exist and be writable
if [[ ! -d ${STATIC_DEF_CONFIG_DIR} ]]
then	
  . ${ZOWE_ROOT_DIR}/scripts/utils/error.sh "Static definition config directory '${STATIC_DEF_CONFIG_DIR}' doesn't exist"
else 	
	if [[ ! -w ${STATIC_DEF_CONFIG_DIR} ]]
	then	
	  . ${ZOWE_ROOT_DIR}/scripts/utils/error.sh "Static definition config directory '${STATIC_DEF_CONFIG_DIR}' does not have write access"	
	fi
fi