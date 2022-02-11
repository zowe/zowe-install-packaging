#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2020, 2021
################################################################################

export ZWE_RUN_ON_ZOS=$(test `uname` = "OS/390" && echo "true")

export _CEE_RUNOPTS="FILETAG(AUTOCVT,AUTOTAG) POSIX(ON)"
export _TAG_REDIR_IN=txt
export _TAG_REDIR_OUT=txt
export _TAG_REDIR_ERR=txt
export _BPXK_AUTOCVT="ON"

# enforce encoding of stdio/stdout/stderr
# sometimes /dev/tty* ($SSH_TTY) are not configured properly, for example tagged as binary or wrong encoding
export NODE_STDOUT_CCSID=1047
export NODE_STDERR_CCSID=1047
export NODE_STDIN_CCSID=1047

export _EDC_ADD_ERRNO2=1                        # show details on error
unset ENV             # just in case, as it can cause unexpected output
umask 0002                                       # similar to chmod 755

# Workaround Fix for node 8.16.1 that requires compatibility mode for untagged files
export __UNTAGGED_READ_MODE=V6
