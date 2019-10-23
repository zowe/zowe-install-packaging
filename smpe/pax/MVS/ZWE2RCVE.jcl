//ZWE2RCVE JOB <job parameters>
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
//* This JCL will SMP/E RECEIVE product
//* Zowe Open Source Project
//*
//*
//* CAUTION: This is neither a JCL procedure nor a complete job.
//* Before using this job step, you will have to make the following
//* modifications:
//*
//* 1) Add the job parameters to meet your system requirements.
//*
//* 2) Change #csihlq to the high level qualifier for the global zone
//*    of the CSI.
//*
//* 3) Change #hlq to the high level qualifier(s) of the SMPMCS and
//*    REL files, as specified when uploading the files to the host
//*    (as described in the program directory).
//*
//* Note(s):
//*
//* 1. If #hlq is blank you must remove the RFPREFIX operand.
//*
//* 2. SMP/E makes copies of the relfiles and uses these as input.
//*    Uncomment and customize DD SMPTLIB if you want to place these
//*    copies on a specific volume.
//*
//* 3. This job should complete with a return code 0.
//*
//********************************************************************
//         EXPORT SYMLIST=(HLQ)
//*
//         SET HLQ=#hlq
//*
//RECEIVE  EXEC PGM=GIMSMP,REGION=0M,COND=(4,LT)
//SMPCSI   DD DISP=OLD,DSN=#csihlq.CSI
//*SMPTLIB  DD UNIT=SYSALLDA,SPACE=(TRK,(1,1)),VOL=SER=#csivol
//SMPHOLD  DD DUMMY
//SMPPTFIN DD DISP=SHR,DSN=&HLQ..[RFDSNPFX].[FMID].SMPMCS
//SMPCNTL  DD *,SYMBOLS=JCLONLY
   SET BOUNDARY(GLOBAL) .
   RECEIVE SELECT([FMID])
           SYSMODS
           RFPREFIX(&HLQ)
           LIST .
//*
