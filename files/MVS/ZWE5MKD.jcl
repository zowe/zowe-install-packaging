//ZWE5MKD  JOB <job parameters>
//*
//* This program and the accompanying materials are made available
//* under the terms of the Eclipse Public License v2.0 which
//* accompanies this distribution, and is available at
//* https://www.eclipse.org/legal/epl-v20.html
//*
//* SPDX-License-Identifier: EPL-2.0
//*
//* 5698-ZWE Copyright Contributors to the Zowe Project. 2019, [YEAR]
//*
//********************************************************************
//*
//* This JCL will create directories for product
//* Zowe Open Source Project
//*
//*
//* CAUTIONS:
//* A) This job contains case sensitive path statements.
//* B) This is neither a JCL procedure nor a complete job.
//*    Before using this JCL, you will have to make the following
//*    modifications:
//*
//* 1) Add the job parameters to meet your system requirements.
//*
//* 2) Change the string "-PathPrefix-" to the appropriate
//*    high level directory name with leading and trailing "/". For
//*    users installing in the root this would be "/". For others,
//*    the high level directory may be something like "/service/",
//*    or a more meaningful name.
//*
//*    Please note that the replacement string is case sensitive.
//*
//*    If you used the optional ZWE4ZFS job, "-PathPrefix-" must
//*    match the value for the same variable in that job.
//*
//* 3a) If you are APPLYing this function for the first time, change
//*    #dsprefix to the value specified for DSPREFIX in the OPTIONS
//*    entry of the GLOBAL zone.
//*    If you used the optional ZWE1SMPE job to define the CSI,
//*    the #dsprefix value will match the CSI high level qualifier.
//*
//* 3b) If you are running this job to install service after the
//*    product has been APPLYed, the ZWEMKDIR EXEC will reside in
//*    a target library.
//*    - Uncomment the second SYSEXEC statement and comment out the
//*      first one.
//*    - Change #thlq to the high level qualifier of the target
//*      library, as used in the ZWE3ALOC job.
//*    - Change #tvol to the volser of the target library, as used
//*      in the ZWE3ALOC job.
//*
//* Note(s):
//*
//* 1. Ensure that -PathPrefix- is an absolute path name and begins
//*    and ends with a slash (/).
//*
//* 2. Ensure the directory specified by -PathPrefix- exists prior
//*    to running this job.
//*
//* 3. Ensure you execute this job with a userid that is UID 0, or
//*    that is permitted to the 'BPX.SUPERUSER' profile in the
//*    FACILITY security class.
//*
//* 4. This job should complete with a return code 0.
//*    If not, check the output, consult the z/OS UNIX System
//*    Services Messages and Codes manual to correct the problem,
//*    and resubmit this job.
//*
//********************************************************************
//*
//MKDIR    EXEC PGM=IKJEFT1A,REGION=0M,COND=(4,LT)
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD *
PROFILE MSGID
ZWEMKDIR -PathPrefix-
//*
//SYSEXEC  DD DISP=SHR,DSN=#dsprefix.[FMID].F1
//*
//*SYSEXEC  DD DISP=SHR,         use when requested for service install
//*            UNIT=SYSALLDA,
//*            VOL=SER=#tvol,
//*            DSN=#thlq.SZWESAMP
//*
