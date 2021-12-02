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


# node.js instance is not fully cleaned up when exits. As time going, the message
# queue will be full and any node.js command will generate this error:
#
# msgget: EDC5133I No space left on device. (errno2=0x07050305)
# CEE5207E The signal SIGABRT was received.
# Ended with rc=131
#
# FIXME: this is a temporary workaround suggested by node.js team.
# export __IPC_CLEANUP=1
#
# Always export __IPC_CLEANUP=1 caused another problem which the node.js process
# may randomly hang on __getipc().
#
# This is proper way to cleanup IPC message queues.

id=$(id -nu)
for s in $(ipcs -a | awk 'match($1,"q|m|s") && $5 == "'${id}'" {print $1","$2":"$16}'); do
    x=${s%%:*}
    pid=${s##*:}
    type=${x%%,*}
    num=${x##*,}
    if [[ $pid -gt 0 ]]; then
        kill -0 "$pid" 1>/dev/null 2>&1
        if [ $? -eq 0 ]; then
            true
        else
            ipcrm -$type $num
        fi
    else
        ipcrm -$type $num
    fi
done
