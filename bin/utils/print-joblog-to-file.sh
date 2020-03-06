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

# Function: Print a JES job log to a USS file
#
# Inputs  - jobname   - the name of the job
#         - jobid     - JES JobID of job, like job00000, stc00000 or tsu00000
# Lowercase is treated as uppercase in jobname and jobid
#
# Outputs - jobfile   - the USS filename to receive the output
#
# The job will be purged from the JES spool
# Uses    - The TSO OUTPUT command

# identify this script
SCRIPT_DIR="$(dirname $0)"
SCRIPT="$(basename $0)"
echo script $SCRIPT started from $SCRIPT_DIR

if [[ $# -ne 3 ]]
then
echo; echo $SCRIPT Usage:
cat <<EndOfUsage

    $SCRIPT jobname jobid jobfile

for example

    $SCRIPT myjob   job65262 myjob.out
    $SCRIPT zwe1sv  stc00406 /u/userid/zowestc.out

The output will be placed in jobfile and the job will be purged.
EndOfUsage
echo script $SCRIPT ended 
exit 
fi

jobname=$1
jobid=$2
jobfile=$3

userid=${USER:-${USERNAME:-${LOGNAME}}}
tsoJobname=RUNTSOCM
if [ -z ${TEMP_DIR+x} ]; then
    TEMP_DIR=${TMPDIR:-/tmp}
fi
tsoCommandOut=${TEMP_DIR}/print.job.log.$$.tso.out

cat > ${TEMP_DIR}/runtso1.jcl <<EndOfJCL1
//$tsoJobname JOB REGION=0M
//         EXEC PGM=IKJEFT01
//SYSTSPRT DD PATH='$tsoCommandOut',
//            PATHOPTS=(OWRONLY,OCREAT,OTRUNC),
//            PATHMODE=SIRWXU,FILEDATA=TEXT
//SYSOUT   DD  SYSOUT=*
//SYSTSIN  DD  *
output $jobname($jobid) print($jobname.$jobid)
EndOfJCL1

# submit the job
response=`submit ${TEMP_DIR}/runtso1.jcl`
rc=$?
rm  ${TEMP_DIR}/runtso1.jcl
if [[ $rc -ne 0 ]]
then
    echo $SCRIPT submit JCL $tsoJobname failed
    echo script $SCRIPT failed
    exit 1
fi

echo $response | grep "JOB JOB[0-9]* submitted" 1> /dev/null
if [[ $? -ne 0 ]]
then
    echo $SCRIPT failed to obtain JES job number of $tsoJobname
    echo script $SCRIPT failed
    exit 2
fi

# extract the number of the job that prints the log
jesjobnumber=`echo $response | sed "s/.*JOB JOB\([0-9]*\) submitted.*/\1/"`

jobdone=0    # has the job that prints the log finished yet?
for secs in 1 2 3 4 5
do
    sleep $secs
    tsocmd status "$tsoJobname(job$jesjobnumber)" 2> /dev/null | grep "ON OUTPUT QUEUE" 1> /dev/null
    if [[ $? -eq 0 ]]
    then
        # echo $SCRIPT job "$tsoJobname(job$jesjobnumber)" completed
        jobdone=1
        break
    fi
done

if [[ $jobdone -ne 1 ]]
then
    echo $SCRIPT job "$tsoJobname(job$jesjobnumber)" not run in time
    echo script $SCRIPT failed
    exit 3
fi

# A successful $tsoCommandOut file looks like this

#         1READY
#          output RUNTSOCM(JOB65503) print(RUNTSOCM.JOB65503)
#          READY
#          END

# any extra message indicates an error

if [[ `cat $tsoCommandOut | wc -l` -ne 4 ]]
then
    echo ====== TSO OUTPUT command log begin
    cat $tsoCommandOut
    echo ====== TSO OUTPUT command log end 

    grep "IKJ56328I JOB .* REJECTED - JOBNAME MUST BE YOUR USERID OR MUST START WITH YOUR USERID" $tsoCommandOut 1> /dev/null
    if [[ $? -eq 0 ]]
    then
        echo $SCRIPT Cannot collect job output due to site restriction on TSO OUTPUT command.
        echo $SCRIPT Please collect job output manually.
    else
        echo $SCRIPT Error obtaining output for "$jobname($jobid)"  
    fi

    echo script $SCRIPT failed
    rm  $tsoCommandOut
    exit 4
fi

rm  $tsoCommandOut

cp "//$jobname.$jobid.outlist" $jobfile
if [[ $? -eq 0 ]]
then
    echo $SCRIPT job output of "$jobname($jobid)" copied to $jobfile
    tsocmd delete $jobname.$jobid.outlist 1> /dev/null 2> /dev/null
else
    echo $SCRIPT job output of "$jobname($jobid)" not copied to USS
    echo $SCRIPT Dataset $jobname.$jobid.outlist retained
    echo script $SCRIPT failed
    exit 5
fi

echo script $SCRIPT succeeded 
