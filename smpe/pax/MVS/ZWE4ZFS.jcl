//ZWE4ZFS  JOB <job parameters>
//*
//* This program and the accompanying materials are made available
//* under the terms of the Eclipse Public License v2.0 which
//* accompanies this distribution, and is available at
//* https://www.eclipse.org/legal/epl-v20.html
//*
//* SPDX-License-Identifier: EPL-2.0
//*
//* Copyright Contributors to the Zowe Project. 2019, [YEAR]
//*
//********************************************************************
//*
//* This JCL will create a z/OS UNIX file system, create a
//* z/OS UNIX mount point, and mount the file system for product
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
//* 2) Change the string "#fsdsn" to the appropriate data set name
//*    for the file system that will be created.
//*
//* 3) Change #fsvol to the volser for the file system,
//*    if you choose not to use the default of letting your Automatic
//*    Class Selection (ACS) routines decide which volume to use.
//*    If you use #fsvol, also uncomment all references to it:
//*    - VOLUMES(#fsvol) in step ZFSALLOC
//*
//* 4) Change the string "-PathPrefix-" to the appropriate
//*    high level directory name with leading and trailing "/". For
//*    users installing in the root this would be "/". For others,
//*    the high level directory may be something like "/service/",
//*    or a more meaningful name.
//*
//*    Please note that the replacement string is case sensitive.
//*
//* 5a) If you are APPLYing this function for the first time, change
//*    #dsprefix to the value specified for DSPREFIX in the OPTIONS
//*    entry of the GLOBAL zone.
//*    If you used the optional ZWE1SMPE job to define the CSI,
//*    the #dsprefix value will match the CSI high level qualifier.
//*
//* 5b) If you are running this job to install service after the
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
//* 2. The directory specified by -PathPrefix- will be created by the
//*    job if it does not exist.
//*
//* 3. If your complete path name (-PathPrefix-usr/lpp/zowe) extends
//*    beyond JCL limits, you can split it over multiple lines. The
//*    ZWEMKDIR REXX will strip leading and trailing blanks and
//*    combine all lines in DD ROOT into a single path name.
//*
//* 4. Ensure you execute this job with a userid that is UID 0, or
//*    that is permitted to the 'BPX.SUPERUSER' profile in the
//*    FACILITY security class.
//*
//* 5. The ZFS started task needs READ access to the file system when
//*    mounting a zFS file system. Lacking this permission will
//*    result in errno=79 errnojr=EF096055 for the mount command.
//*
//* 6. You should consider updating the BPXPRMxx PARMLIB member to
//*    mount the file system created with this job at IPL time.
//*
//*    MOUNT FILESYSTEM('#fsdsn')
//*       MOUNTPOINT('-PathPrefix-usr/lpp/zowe')
//*       MODE(RDRW)                 /* can be MODE(READ) */
//*       TYPE(ZFS) PARM('AGGRGROW') /* zFS, with extents */
//*
//* 7. This job should complete with a return code 0.
//*    If not, check the output, consult the z/OS UNIX System
//*    Services Messages and Codes manual to correct the problem,
//*    and resubmit this job.
//*
//********************************************************************
//         EXPORT SYMLIST=(DSN)
//*
//         SET DSN='#fsdsn'
//*
//ZFSALLOC EXEC PGM=IDCAMS,REGION=0M,COND=(4,LT)
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *,SYMBOLS=JCLONLY
   DEFINE CLUSTER( -
     NAME(&DSN) -
   /*VOLUMES(#fsvol)*/ -
     LINEAR -
     TRACKS(9000 900) -
     SHAREOPTIONS(3) -
   )
//*
//ZFSFORMT EXEC PGM=IOEAGFMT,REGION=0M,COND=(4,LT),
//            PARM='-aggregate &DSN -compat'
//*STEPLIB  DD DISP=SHR,DSN=IOE.SIOELMOD        before z/OS 1.13
//*STEPLIB  DD DISP=SHR,DSN=SYS1.SIEALNKE       from z/OS 1.13
//SYSPRINT DD SYSOUT=*
//*
//MOUNT    EXEC PGM=IKJEFT01,REGION=0M,COND=(4,LT),
//            PARM='%ZWEMKDIR ROOT=ROOT MOUNT=&DSN AGGRGROW'
//REPORT   DD SYSOUT=*
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DUMMY
//ROOT     DD DATA,DLM=$$                        data can be multi-line
  -PathPrefix-usr/lpp/zowe
$$
//SYSEXEC  DD DISP=SHR,DSN=#dsprefix.[FMID].F1
//*
//*SYSEXEC  DD DISP=SHR,         use when requested for service install
//*            UNIT=SYSALLDA,
//**            VOL=SER=#tvol,
//*            DSN=#thlq.SZWESAMP
//*
