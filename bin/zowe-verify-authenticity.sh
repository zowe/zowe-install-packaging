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
# Inputs  -	pathname of Zowe runtime driver on your z/OS system
#         -	HashFiles.class (binary)
#         -	RefRuntimeHash-v.r.m.txt (list of files with hash keys)
#  
# SMP/E   - The directory SMPE in the runtime folder is excluded from this check
#           The SMPE directory and contents must not be present in the supplied
#           RefRuntimeHash-v.r.m.txt file, or they will be flagged here as missing
#
# fingerprint
#         - The 'fingerprint' directory in the runtime directory holds 
#           the reference hash key file RefRuntimeHash-v.r.m.txt
#           Like the SMPE directory, it's excluded from the check.
#
# Outputs - Lists of runtime files missing, extra 
#           and different from official Ref version
#           
# Requires- java runtime

SCRIPT=zowe-verify-authenticity
echo $SCRIPT.sh started
notD="does not exist or is not a directory"

while getopts "h:r:f:l:" opt; do
  case $opt in
    r) runtimePath=$OPTARG
        if [[ ! -d $runtimePath ]]
        then
            echo Error: -r $runtimePath $notD
            exit 1
        fi 
        runtimePath=$(cd $runtimePath;pwd)
        ;;
    h) hashPath=$OPTARG
        if [[ ! -d $hashPath ]]
        then
            echo Error: -h $hashPath $notD
            exit 1
        fi    
        hashPath=$(cd $hashPath;pwd)
        ;;
    f) refPath=$OPTARG
        if [[ ! -d $refPath ]]
        then
            echo Error: -f $refPath $notD
            exit 1
        fi
        refPath=$(cd $refPath;pwd)
        ;;
    l) outputPath=$OPTARG
        ;;
    \?)
      echo "Invalid option: -$opt" >&2
      echo; echo $SCRIPT.sh Usage:
cat <<EndOfUsage
$SCRIPT.sh runtimePath hashPath

   Parameter subsitutions:
 
    Parm name       Sample value    Meaning
    ---------       ------------    -------
-r  runtimePath     /usr/lpp/zowe   root directory of the executables used by Zowe at run time
-h  hashPath        /usr/lpp/zowe/bin/internal          directory of the hash key program
-f  refPath         /usr/lpp/zowe/fingerprint           directory of the reference hash key file
-l  outputPath      ~/zowe/fingerprint             output directory where log and work files like 
                                                   CustRuntimeHash.txt will be written.
                                                   This directory Will be created if it does not exist.

EndOfUsage
      exit 1
      ;;
  esac
done

# runtime path
if [[ ! -n "$runtimePath" ]]
then
    # runtimePath was not set by -r
    # Assume script was invoked in location ROOT_DIR/bin
    # Allow relative or absolute path or tilde 
    if [[ ! -d `dirname $0`/.. ]]
    then
        echo Error: Default runtimePath `dirname $0`/.. $notD
        exit 1
    fi
    runtimePath=$(cd `dirname $0`;cd ..;pwd)
fi


# hash path
if [[ ! -n "$hashPath" ]]
then
    if [[ ! -d `dirname $0`/../bin/internal ]]
    then
        echo Error: Default hashPath `dirname $0`/../bin/internal $notD
        exit 1
    fi 
    hashPath=$(cd `dirname $0`;cd ../bin/internal;pwd)
fi


# ref path
if [[ ! -n "$refPath" ]]
then
    if [[ ! -d `dirname $0`/../fingerprint ]]
    then
        echo Error: Default refPath `dirname $0`/../fingerprint $notD
        exit 1
    fi 
    refPath=$(cd `dirname $0`;cd ../fingerprint || exit;pwd)
fi

# Create outputPath directory for log and other new files
umask 0022
if [[ ! -n "$outputPath" ]]
then # create output directory in default location, suffixed 'fingerprint'
    for dir in /global/zowe/log ~/zowe ${TMPDIR:-/tmp}
    do
        mkdir -p $dir/fingerprint 1> /dev/null 2>/dev/null 
        if [[ $? -eq 0 ]]
        then
            outputPath=$dir/fingerprint
            break
        fi
    done
    if [[ ! -n "$outputPath" ]] # still failed to create a directory
    then
        echo Error: Cannot create default outputPath directory 
        exit 1
    fi
else # create specified directory
    mkdir -p $outputPath 1> /dev/null 2>/dev/null 
    if [[ $? -ne 0 ]]
    then
        echo Error: Cannot create specified outputPath directory $outputPath 
        exit 1
    fi     
fi
outputPath=$(cd $outputPath;pwd)    # expand tilde and relative pathnames


# is outputPath contained in runtime?
echo $outputPath | grep ^$runtimePath  1> /dev/null 2> /dev/null
if [[ $? -eq 0 ]]
then
    echo Error: outputPath $outputPath must not be in runtimePath $runtimePath
    exit 1
fi

LOG_FILE=$outputPath/$SCRIPT.log
touch $LOG_FILE
if [[ $? -ne 0 ]]
then
    echo Error: Cannot write to $outputPath
    exit 1
fi

echo Info: Logging to $LOG_FILE
echo "<$SCRIPT.sh>"                 >  $LOG_FILE

echo `date`                         >> $LOG_FILE
echo "runtimePath = $runtimePath"   >> $LOG_FILE
echo "hashPath    = $hashPath"      >> $LOG_FILE
echo "refPath     = $refPath"       >> $LOG_FILE
echo "outputPath  = $outputPath"    >> $LOG_FILE

# - - - - - - - - - - - - - main logic

# Verify runtime directory contents minimally
for dir in bin components scripts manifest.json
do
    ls -l $runtimePath | grep " $dir$" 1> /dev/null 2>/dev/null
    if [[ $? -ne 0 ]]
    then
        echo Error: runtimePath $runtimePath does not contain $dir | tee -a $LOG_FILE
        exit 1
    fi 
done 

# Reference hash file will be named like RefRuntimeHash-1.12.0.txt
# manifest.json will contain a line like this near the top:
#   "version": "1.11.0",
# Extract Zowe version from manifest.json: 

zoweVersion=`head $runtimePath/manifest.json | sed -n 's/ *"version" *: *"\(.*\)".*/\1/p'`
if [[ -n $zoweVersion ]]
then 
    echo Info: zoweVersion = $zoweVersion | tee -a $LOG_FILE
else
    echo Error: Unable to obtain zoweVersion from $runtimePath/manifest.json | tee -a $LOG_FILE
    exit 1
fi

# Verify hash file directory contents minimally
if [[ ! -f $hashPath/HashFiles.class ]]
then
    echo Error: hashPath $hashPath does not contain HashFiles.class file | tee -a $LOG_FILE
    exit 1
fi 

RefRuntimeHash=RefRuntimeHash-$zoweVersion.txt
# Verify refPath directory contents minimally
if [[ ! -f $refPath/$RefRuntimeHash ]]
then
    echo Error: refPath $refPath does not contain $RefRuntimeHash | tee -a $LOG_FILE
    exit 1
fi

# Verify refPath contents minimally
head $refPath/$RefRuntimeHash|grep '^\./' 1> /dev/null 2>/dev/null
if [[ $? -ne 0 ]]
then
    echo Error: Lines at top of file $refPath/$RefRuntimeHash do not start with \"./\" | tee -a $LOG_FILE
    exit 1
fi 

echo Info: Gathering files ... | tee -a $LOG_FILE

cd $runtimePath
find . -name ./SMPE          -prune \
    -o -name "./ZWE*"        -prune \
    -o -name ./fingerprint   -prune \
    -o -type f -print > $outputPath/files.in # exclude SMPE, ZWE* and fingerprint
if [[ $? -ne 0 ]]
then
    echo Error: Failed to generate a list of files from $runtimePath | tee -a $LOG_FILE
    exit 1
fi 


echo Info: Checking java version >> $LOG_FILE
java -version 2>> $LOG_FILE
if [[ $? -ne 0 ]]
then
    echo "Warning: java not in PATH" | tee -a $LOG_FILE
    if [[ -n "$JAVA_HOME" ]]
    then
        echo Info: JAVA_HOME = $JAVA_HOME  >> $LOG_FILE
        $JAVA_HOME/bin/java -version 2>> $LOG_FILE
        if [[ $? -ne 0 ]]
        then
            echo "Error: Cannot find java version in $JAVA_HOME/bin" | tee -a $LOG_FILE
            exit 1
        else
            javaPrefix=$JAVA_HOME/bin/
        fi
    else
        echo "Error: JAVA_HOME is not set" | tee -a $LOG_FILE
        exit 1
    fi
else
    javaPrefix=  # java is in $PATH
fi

echo Info: Calculating hashes ... | tee -a $LOG_FILE

${javaPrefix}java -cp $hashPath HashFiles $outputPath/files.in > $outputPath/CustRuntimeHash.txt
if [[ $? -ne 0 ]]
then
    echo Error: Failed to generate hash files from $runtimePath | tee -a $LOG_FILE
    exit 1
fi

cd $outputPath
rm files.in 

# sort the results to make comparison easier
sort CustRuntimeHash.txt                > CustRuntimeHash.sort
sort $refPath/$RefRuntimeHash           > RefRuntimeHash.sort

echo Info: Comparing results ... | tee -a $LOG_FILE

# establish differences
maxDiffs=10
comm -3 RefRuntimeHash.sort CustRuntimeHash.sort > comm-3.txt
nDiff=`wc -l comm-3.txt | awk '{print $1}'`
echo "Info: Number of files different = " $nDiff | tee -a $LOG_FILE

# for missing/extra, compare names only
awk '{print $1}' RefRuntimeHash.sort    > ref-filenames.txt
awk '{print $1}' CustRuntimeHash.sort   > cust-filenames.txt

# extra
comm -13 ref-filenames.txt cust-filenames.txt > comm-13.txt
nExtra=`wc -l comm-13.txt | awk '{print $1}'`
echo "Info: Number of files extra     = " $nExtra | tee -a $LOG_FILE

# missing
comm -23 ref-filenames.txt cust-filenames.txt > comm-23.txt
nMissing=`wc -l comm-23.txt | awk '{print $1}'`
echo "Info: Number of files missing   = " $nMissing | tee -a $LOG_FILE

rm ref-filenames.txt cust-filenames.txt 

# different
echo >> $LOG_FILE
if [[ $nDiff -gt 0 ]] # skip if no files are different
then
    echo Info: First $maxDiffs matching filenames with different hashes >> $LOG_FILE
    i=0
    while read file hash
    do
        if [[ $file = $oldfile ]]
        then
            echo $file >> $LOG_FILE 
            let "i=i+1" 
            if [[ $i -gt $maxDiffs ]]
            then
                echo Info: More than $maxDiffs differences, no further differences are listed >> $LOG_FILE
                break
            fi 
        fi
        oldfile=$file
        oldhash=$hash
    done < comm-3.txt

    echo >> $LOG_FILE
fi
rm comm-3.txt

if [[ $nExtra -gt 0 ]]
then
    echo Info: First 10 extra files >> $LOG_FILE
    head comm-13.txt | awk '{ print $1 }' >> $LOG_FILE
    echo >> $LOG_FILE
fi
rm   comm-13.txt
    
if [[ $nMissing -gt 0 ]]
then
    echo Info: First 10 missing files >> $LOG_FILE
    head comm-23.txt | awk '{ print $1 }' >> $LOG_FILE
    echo >> $LOG_FILE
fi
rm   comm-23.txt
    
echo "Info: Customer  runtime hash files are available in " >> $LOG_FILE
ls $outputPath/CustRuntimeHash.* >> $LOG_FILE
echo >> $LOG_FILE
echo "Info: Reference runtime hash files are available in " >> $LOG_FILE
ls $outputPath/RefRuntimeHash* >> $LOG_FILE
ls $refPath/$RefRuntimeHash    >> $LOG_FILE
echo >> $LOG_FILE

if [[ $nDiff -eq 0 && $nExtra -eq 0 && $nMissing -eq 0 ]]
then
    echo Info: Verification PASSED | tee -a $LOG_FILE
    RC=0
else
    echo Error: Verification FAILED | tee -a $LOG_FILE
    RC=1
fi

echo Info:  Result files and script log are in directory $outputPath

echo $SCRIPT.sh ended
echo "</$SCRIPT.sh>" >> $LOG_FILE
exit $RC