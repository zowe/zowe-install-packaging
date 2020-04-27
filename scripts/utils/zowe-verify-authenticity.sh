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

#	zowe-verify-authenticity.sh

# Function: Verify the authenticity of a Zowe runtime driver
# Method  : Create a hash of every file in the driver and compare them 
#           to the hashes of the official version.  
# Inputs  - pathname of Zowe runtime driver on your z/OS system
#         - Downloaded from zowe.org:
#           •	HashFiles.class (binary)
#           •	RefRuntimeHash.txt (list of files with hash keys)
#           •	RefRuntimeHashHash.txt (hash of the above list)
# Note about SMP/E
#         - The directory SMPE in the runtime folder is excluded from this check
#           The SMPE directory and contents must not be present in the supplied
#           RefRuntimeHash.txt file, or they will be flagged as missing

# Outputs - Lists of runtime files missing, extra and different from official version
#           
# Uses    - java class Hashfiles.class
SCRIPT=zowe-verify-authenticity.sh

if [[ $# -ne 2 ]]   
then
echo; echo $SCRIPT Usage:
cat <<EndOfUsage
$SCRIPT runtimePath hashPath

   Parameter subsitutions:
 
    Parm name       Sample value    Meaning
    ---------       ------------    -------
 1  runtimePath     /usr/lpp/zowe   root directory for the executables used by Zowe at run time
 2  hashPath        ~/hash          writable work directory where you have downloaded the reference hash key files and program

EndOfUsage
exit
fi

runtimePath=$1
hashPath=$2

# Allow for ~ in path
runtimePath=`sh -c "echo ${runtimePath}"` 
# If the path is relative, then expand it
if [[ "$runtimePath" != /* ]]
then
# Relative path
runtimePath=$PWD/$runtimePath
fi

# Allow for ~ in path
hashPath=`sh -c "echo ${hashPath}"` 
# If the path is relative, then expand it
if [[ "$hashPath" != /* ]]
then
# Relative path
hashPath=$PWD/$hashPath
fi

# Verify runtime directory contents minimally
for dir in bin components scripts
do
    ls -l $runtimePath | grep " $dir$" 1> /dev/null 2>/dev/null
    if [[ $? -ne 0 ]]
    then
        echo Error: directory $runtimePath does not contain $dir
        exit 1
    fi 
done 

# Verify hash file directory contents minimally
for file in HashFiles.class RefRuntimeHash.txt RefRuntimeHashHash.txt
do
    ls -l $hashPath | grep " $file$" 1> /dev/null 2>/dev/null
    if [[ $? -ne 0 ]]
    then
        echo Error: directory $hashPath does not contain $file
        exit 1
    fi 
done 

# Verify hash file contents minimally
head $hashPath/RefRuntimeHash.txt|grep '^\./' 1> /dev/null 2>/dev/null
if [[ $? -ne 0 ]]
then
    echo Error: Lines at top of file $hashPath/RefRuntimeHash.txt do not start with \"./\"
    exit 1
fi 

echo Info: Gathering files ...

cd $runtimePath
find . -name ./SMPE -prune -o -type f -print > $hashPath/files.in # exclude SMPE
if [[ $? -ne 0 ]]
then
    echo Error: Failed to generate a list of files from $runtimePath
    exit 1
fi 

echo Info: Calculating hashes ...

java -cp $hashPath HashFiles $hashPath/files.in > $hashPath/CustRuntimeHash.txt
if [[ $? -ne 0 ]]
then
    echo Error: Failed to generate hash files from $hashPath
    exit 1
fi

cd $hashPath
echo CustRuntimeHash.txt > files.in  # put one file name in list of files to be hashed
java HashFiles files.in > CustRuntimeHashHash.txt
if [[ $? -ne 0 ]]
then
    echo Error: Failed to generate hash file from CustRuntimeHash.txt
    # exit 1
fi

# sort the results to make comparison easier
sort CustRuntimeHash.txt > CustRuntimeHash.sort
sort RefRuntimeHash.txt  > RefRuntimeHash.sort

echo Info: Comparing results ...

# establish differences
maxDiffs=50
comm -3 RefRuntimeHash.sort CustRuntimeHash.sort > file3
nDiff=`cat file3 | wc -l`
echo "Info: Number of files different = " $nDiff

nExtra=`comm -13 RefRuntimeHash.sort CustRuntimeHash.sort | wc -l`
echo "Info: Number of files extra     = " $nExtra

nMissing=`comm -23 RefRuntimeHash.sort CustRuntimeHash.sort | wc -l`
echo "Info: Number of files missing   = " $nMissing

echo Info: List of matching files with different hashes
echo
i=0
while read file hash
do
    if [[ $file = $oldfile ]]
    then
        echo $file $hash
        echo $oldfile $oldhash
        echo
        let "i=i+1" 
        if [[ $i -gt $maxDiffs ]]
        then
            echo Info: More than $maxDiffs differences, no further differences are listed
            break
        fi 
    fi
    oldfile=$file
    oldhash=$hash
done < file3

echo Info: End of list
echo

echo Info: differences in overall hash
comm -3 RefRuntimeHashHash.txt CustRuntimeHashHash.txt
echo
echo "Info: Customer  runtime hash file is available in " $hashPath/CustRuntimeHash.txt 
echo "Info: Reference runtime hash file is available in " $hashPath/RefRuntimeHash.txt 

rm files.in CustRuntimeHash.sort RefRuntimeHash.sort file3