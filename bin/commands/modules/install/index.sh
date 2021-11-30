#!/bin/sh

#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.
#######################################################################

zwecli_inline_execute_command modules install extract
# ZWE_MODULES_INSTALL_EXTRACT_COMPONENT_NAME should be set after extract step
if [ -n "${ZWE_MODULES_INSTALL_EXTRACT_COMPONENT_NAME}" ]; then
  zwecli_inline_execute_command modules install process-hook --module-name "${ZWE_MODULES_INSTALL_EXTRACT_COMPONENT_NAME}"
else
  print_error_and_exit "Error ZWES0156E: Component name is not initialized after extract step." "" 156
fi
