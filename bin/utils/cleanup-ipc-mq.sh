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
# Trying to capture columns T, ID, and second to last column, which for q=LSPID, m=CPID
for s in $(ipcs -a | awk 'match($1,"q|m") && $5 == "'${id}'" { print "type=\""$1"\";num=\""$2"\";pidOne=\""$(NF-1)"\";pidTwo=\""$(NF)"\"" }'); do    
    eval "${s}"
    if [ $pidOne -gt 0 ] && [ $pidTwo -gt 0 ]; then
        kill -0 "$pidOne" 1>/dev/null 2>&1
        if [ $? -ne 0 ]; then
            kill -0 "$pidTwo" 1>/dev/null 2>&1
            if [ $? -ne 0 ]; then   # Neither pid exists, safe to remove q/m
                ipcrm -$type $num 1>/dev/null 2>&1
            fi
        fi
    fi
done

# Trying to capture columns T, ID, WTRPID. When WTRPID is empty, semaphore is orphaned.
for s in $(ipcs -sw | awk 'match($1,"s") && $3 == "'${id}'" { print "sem=\""$2"\";pid=\""$5"\"" }'); do
    eval "${s}"
    if [[ $pid -eq 0 ]]; then
        ipcrm -s $sem 1>/dev/null 2>&1
    fi
done
