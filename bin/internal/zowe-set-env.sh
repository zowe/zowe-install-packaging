#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2020, 2020
#######################################################################

export _CEE_RUNOPTS="FILETAG(AUTOCVT,AUTOTAG) POSIX(ON)"
export _TAG_REDIR_IN=txt
export _TAG_REDIR_OUT=txt
export _TAG_REDIR_ERR=txt
export _BPXK_AUTOCVT="ON"

export _EDC_ADD_ERRNO2=1                        # show details on error
unset ENV             # just in case, as it can cause unexpected output
umask 0002                                       # similar to chmod 775
# TODO why 0002 and not 0022? 0002 is 775, 0022 is 755

# Workaround Fix for node 8.16.1 that requires compatability mode for untagged files
export __UNTAGGED_READ_MODE=V6
