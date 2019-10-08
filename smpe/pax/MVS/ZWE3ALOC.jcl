//ZWE3ALOC JOB <job parameters>
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
//* This JCL will allocate target and distribution libraries for
//* Zowe Open Source Project
//*
//*
//* CAUTION: This is neither a JCL procedure nor a complete job.
//* Before using this job step, you will have to make the following
//* modifications:
//*
//* 1) Add the job parameters to meet your system requirements.
//*
//* 2) Change #thlq to the appropriate high level qualifier(s) for
//*    the target data sets. The maximum length is 35 characters.
//*
//* 3) Change #dhlq to the appropriate high level qualifier(s) for
//*    the distribution datasets. The maximum length is 35 characters.
//*
//* 4) Change DSP=CATLG on the EXEC statements to the appropriate
//*    final disposition of the data sets if you choose not to use
//*    the default.
//*
//* 5) By default, this job relies on your Automatic Class Selection
//*    (ACS) routines to place the target data sets. You can
//*    place the data sets on a specific volume when you:
//*    a) Change #tvol to the volser for the target libraries.
//*    b) Uncomment all references to variable &TVOL:
//*       - VOL=SER=&TVOL in multiple DDs of step ALLOCT
//*
//* 6) By default, this job relies on your Automatic Class Selection
//*    (ACS) routines to place the distribution data sets. You can
//*    place the data sets on a specific volume when you:
//*    a) Change #dvol to the volser for the target libraries.
//*    b) Uncomment all references to variable &DVOL:
//*       - VOL=SER=&DVOL in multiple DDs of step ALLOCD
//*
//* Note(s):
//*
//* 1. If you specify a volume for any data set in this job, you
//*    must also specify the same volume in the corresponding
//*    DDDEF entry in the DDDEF job, ZWE6DDEF.
//*    Also ensure that SMS routines will not change the specified
//*    volser during allocation of the data set.
//*
//* 2. This job uses PDSE data sets. If required, you can comment out
//*    all occurances of DSNTYPE=LIBRARY to use PDS data sets instead.
//*
//* 3. Run only the steps that are applicable to your installation.
//*
//* 4. This job WILL complete with a return code 0.
//*    You must check allocation messages to verify that the
//*    data sets are allocated and cataloged as expected.
//*
//********************************************************************
//*
//* ALLOCATE TARGET LIBRARIES
//*
//ALLOCT   PROC THLQ=,
//            TVOL=,
//            DSP=
//*
//ALLOCT   EXEC PGM=IEFBR14,COND=(4,LT),PARM='&TVOL'
//SZWEAUTH DD SPACE=(TRK,(15,5,5)),
//            UNIT=SYSALLDA,
//*           VOL=SER=&TVOL,
//            DISP=(NEW,&DSP),
//            DSNTYPE=LIBRARY,
//            RECFM=U,
//            LRECL=0,
//            BLKSIZE=6999,
//            DSN=&THLQ..SZWEAUTH
//*
//SZWESAMP DD SPACE=(TRK,(15,5,5)),
//            UNIT=SYSALLDA,
//*           VOL=SER=&TVOL,
//            DISP=(NEW,&DSP),
//            DSNTYPE=LIBRARY,
//            RECFM=FB,
//            LRECL=80,
//            BLKSIZE=0,
//            DSN=&THLQ..SZWESAMP
//*
//EALLOCT  PEND
//*
//* ALLOCATE DISTRIBUTION LIBRARIES
//*
//ALLOCD   PROC DHLQ=,
//*           DVOL=,
//            DSP=
//*
//ALLOCD   EXEC PGM=IEFBR14,COND=(4,LT),PARM='&DVOL'
//AZWEAUTH DD SPACE=(TRK,(15,5,5)),
//            UNIT=SYSALLDA,
//*           VOL=SER=&DVOL,
//            DISP=(NEW,&DSP),
//            DSNTYPE=LIBRARY,
//            RECFM=U,
//            LRECL=0,
//            BLKSIZE=6999,
//            DSN=&DHLQ..AZWEAUTH
//*
//AZWESAMP DD SPACE=(TRK,(15,5,5)),
//            UNIT=SYSALLDA,
//*           VOL=SER=&DVOL,
//            DISP=(NEW,&DSP),
//            DSNTYPE=LIBRARY,
//            RECFM=FB,
//            LRECL=80,
//            BLKSIZE=0,
//            DSN=&DHLQ..AZWESAMP
//*
//AZWEZFS  DD SPACE=(TRK,(12000,3000,30)),
//            UNIT=SYSALLDA,
//*           VOL=SER=&DVOL,
//            DISP=(NEW,&DSP),
//            DSNTYPE=LIBRARY,
//            RECFM=VB,
//            LRECL=6995,
//            BLKSIZE=0,
//            DSN=&DHLQ..AZWEZFS
//*
//EALLOCD  PEND
//*
//*  The following steps execute the PROCs to allocate the data sets
//*  for this product. Remove these steps if the data sets already
//*  exist with proper allocations.
//*
//ALLOCT   EXEC ALLOCT,       * Allocate Target Libraries
//*                         1         2         3
//*                12345678901234567890123456789012345
//            THLQ=#thlq,
//            TVOL=#tvol,
//            DSP=CATLG
//*
//ALLOCD   EXEC ALLOCD,       * Allocate Distribution Libraries
//*                         1         2         3
//*                12345678901234567890123456789012345
//            DHLQ=#dhlq,
//            DVOL=#dvol,
//            DSP=CATLG
//*
