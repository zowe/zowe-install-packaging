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

# - STATIC_DEF_CONFIG_DIR - Should exist and be writable
if [[ ! -d ${STATIC_DEF_CONFIG_DIR} ]]
then	
  . ${ROOT_DIR}/scripts/utils/error.sh "Static definition config directory '${STATIC_DEF_CONFIG_DIR}' doesn't exist"
else 	
	if [[ ! -w ${STATIC_DEF_CONFIG_DIR} ]]
	then	
	  . ${ROOT_DIR}/scripts/utils/error.sh "Static definition config directory '${STATIC_DEF_CONFIG_DIR}' does not have write access"	
	fi
fi