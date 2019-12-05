//*--------------------------------------------------------------------
//* This program and the accompanying materials are made available
//* under the terms of the Eclipse Public License v2.0 which
//* accompanies this distribution, and is available at
//* https://www.eclipse.org/legal/epl-v20.html
//*
//* SPDX-License-Identifier: EPL-2.0
//*
//* Copyright Contributors to the Zowe Project. 2019, 2019
//*--------------------------------------------------------------------
//*
//* PROC to merge SYSMOD parts
//*
//* limit to 127 calls per JCL to avoid hitting JCL EXEC PGM limit (255)
//*
//*--------
//PTFMERGE PROC PART=,                    * part name Fx(<member>)
//            HLQ=&HLQ,                   * work HLQ
//            SYSMOD=&SYSMOD,             * output dataset
//            SYSOUT=&SYSOUT,             * dataset collecting SYSPRINT
//            DSP='DELETE',               * final DISP of input file
//* tools invoked in steps (override possible for debug purposes)
//            XMRK=RXDDALOC,              * REXX to allocate marker DD
//            TOOL=&TOOL                  * DSN holding REXX
//*
//* limit fixed MLQ to max 2 char to allow 32 chars for HLQ
//* SMP/E part in seq FB80 format   * KEEP IN SYNC WITH smpe-service.sh
//         SET $PART=&HLQ..#mlq.&PART
//*
//* create marker DD
//* on failure marker DD shows which file (&PART) was being processed
//*
//MARKER   EXEC PGM=IKJEFT01,REGION=0M,COND=(4,LT),
//            PARM='%&XMRK &PART'
//SYSPROC  DD DISP=SHR,DSN=&TOOL
//SYSTSPRT DD DISP=MOD,DSN=&SYSOUT
//SYSTSIN  DD DUMMY
//*
//* add part to sysmod
//*
//MERGE    EXEC PGM=IEBGENER,REGION=0M,COND=(4,LT)
//SYSPRINT DD DISP=MOD,DSN=&SYSOUT
//SYSIN    DD DUMMY
//SYSUT2   DD DISP=MOD,DSN=&SYSMOD
//SYSUT1   DD DISP=(OLD,&DSP),DSN=&$PART
//*
//         PEND
//*--------
//*
