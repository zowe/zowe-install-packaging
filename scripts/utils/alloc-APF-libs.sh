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
# Create the datasets used by the XMEM server in its PROC
#   $datasetprefix.SZISLOAD
#   $datasetprefix.SZISAMP
# These are customer site datasets and will normally exist.
# If they exist, don't try to create them, and don't check them.  
# Attempt to APF-authorise the SZISLOAD.

script=alloc-APF-libs.sh
echo "<$script>" 

if [[ $# -ne 2 ]]   
then
echo; echo $script Usage:
cat <<EndOfUsage
$script datasetprefix volser

   Parameter subsitutions:
 
    Parm name       Value used      Meaning
    ---------       ----------      -------
 1  datasetprefix   ZOE.ZIS         DSN prefix for SZISLOAD and SISSAMP
 2  volser          USER10          volume serial number of a DASD volume to hold MVS datasets 

EndOfUsage
exit
fi

sizeAUTH='space(30,15) tracks'
sizeSAMP='space(15,15) tracks'
datasetprefix=$1
volume=$2



# Statements below must not exceed col 80
#----------------------------------------------------------------------------80|
# cat > ZWESIPRG <<EndOfZWESIPRG
# /* issue this console command to authorize the loadlib temporarily */
# SETPROG APF,ADD,DSNAME=${datasetprefix}.SZISLOAD,VOLUME=${volume}
# /* Add this statement to SYS1.PARMLIB(PROGxx) or equivalent
#    to authorize the loadlib permanently */
# APF ADD DSNAME(${datasetprefix}.SZISLOAD) VOLUME(${volume})
# EndOfZWESIPRG
#----------------------------------------------------------------------------80|

# <<<<

# 1. {datasetprefix}.SZISLOAD

tsocmd "listds '${datasetprefix}.SZISLOAD' " 1> /dev/null 2> /dev/null
if [[ $? -eq 0 ]]
then 
    echo "  ${datasetprefix}.SZISLOAD already exists"
else 
    # SZISLOAD must be PDSE
    # TODO replace by allocate-dataset.sh call to resuse VOLSER support
    tsocmd "allocate new da('${datasetprefix}.SZISLOAD') " \
        "dsntype(library) dsorg(po) recfm(u) lrecl(0) blksize(32760)" \
        "unit(sysallda) $sizeAUTH" 
    rc=$?
    if test $rc -eq 0
    then
        echo "  ${datasetprefix}.SZISLOAD successfully created" 
    else
        echo "  $script failed to create ${datasetprefix}.SZISLOAD, RC=$rc" 
    fi
fi 

# -- APF-authorise the SZISLOAD
# ${CIZT_INSTALL_DIR} is set in the pipeline
${CIZT_INSTALL_DIR}/opercmd "SETPROG APF,ADD,DSNAME=${datasetprefix}.SZISLOAD,VOLUME=${volume}"

# -- you also have to set the PPT entry 
# IEE252I MEMBER IEASYS00 FOUND IN FEU.Z23B.PARMLIB   
# IEA325I IEASYS00 PARAMETER LIST                     
# SCH=00,                         SELECT SCHED00   
# IEE252I MEMBER SCHED00 FOUND IN ADCD.Z23B.PARMLIB
            
# PPT PGMNAME(ZWESIS01) KEY(4) NOSWAP

# SET SCH=00                                                          
# IEE252I MEMBER  SCHED00 FOUND IN ADCD.Z23B.PARMLIB                  
# IEF729I MT STATEMENT IGNORED, NOT SUPPORTED FOR DYNAMIC UPDATE.     
# IEE536I SCH      VALUE 00 NOW IN EFFECT   


# 2. {datasetprefix}.SISSAMP

tsocmd "listds '${datasetprefix}.SISSAMP' " 
if [[ $? -eq 0 ]]
then 
    echo "  ${datasetprefix}.SISSAMP already exists"
else 
    # TODO replace by allocate-dataset.sh call to resuse VOLSER support
    tsocmd "allocate new da('${datasetprefix}.SISSAMP') " \
        "dsntype(library) dsorg(po) recfm(f b) lrecl(80) " \
        "unit(sysallda) $sizeSAMP" 
    rc=$?
    if test $rc -eq 0
    then
        echo "  ${datasetprefix}.SISSAMP successfully created" 
    else
        echo "  $script failed to create ${datasetprefix}.SISSAMP, RC=$rc" 
    fi
fi 

echo "</$script>" 
