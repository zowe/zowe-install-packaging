#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2020
#######################################################################

#	zowe-generate-checksum.sh
# 

# Function: Create the checksum files of the runtime directory files.
# Method  : Create a hash of every file in the driver 
# Inputs  - pathname of Zowe runtime driver on the build's z/OS system
#         - pathname where the source of HashFiles.java is kept
#           This is currently zowe-install-packaging/files
# Note about SMP/E
#         - The directory SMPE in the runtime folder is excluded from this check
#           The SMPE directory and contents must not be present in the generated
#           RefRuntimeHash.txt file, or they will be flagged as missing
#           at compare time.  

# Outputs 
#           •	HashFiles.class (binary)
#           •	RefRuntimeHash.txt (list of files with hash keys)
#           
# Uses    - java compiler
SCRIPT=zowe-generate-checksum.sh
echo $SCRIPT started

if [[ $# -ne 2 ]]   
then
echo; echo $SCRIPT Usage:
cat <<EndOfUsage
$SCRIPT runtimePath hashPath

   Parameter substitutions:
 
    Parm name       Sample value    Meaning
    ---------       ------------    -------
 1  runtimePath     /usr/lpp/zowe   root directory for the executables used by Zowe at run time
 2  hashPath        scripts/utils   writable work directory where you want the reference hash key file and program created

EndOfUsage
exit
fi

runtimePath=$1
hashPath=$2

echo List of runtimePath contents
ls $runtimePath
echo List of hashPath contents
ls $hashPath

cd $hashPath
javac HashFiles.java 
cp    HashFiles.class    $runtimePath/bin/internal # must be in runtime before you hash runtime.  

# Create a list of files to be hashed.  Exclude SMPE.  And fingerprint.  
cd $runtimePath
. bin/internal/zowe-set-env.sh # ensure we have tagging behaviour set correctly

ls fingerprint/* 2> /dev/null # is there an existing fingerprint?
if [[ $? -eq 0 ]]
then
    echo $SCRIPT Warning: fingerprint already exists
fi

find . -name ./SMPE             -prune \
    -o -name "./ZWE*"           -prune \
    -o -name ./fingerprint      -prune \
    -o -type f -print > $hashPath/files.in 
# create the set of hashes
java -cp $hashPath HashFiles $hashPath/files.in > $hashPath/RefRuntimeHash.txt
echo HashFiles RC=$?

rm $hashPath/files.in
echo $SCRIPT ended
