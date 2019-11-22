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
//* PROC to stage file for SYSMOD creation, generic back-end
//*
//* PROC logic:
//* IF (RC <= 4) THEN
//*   MARKER   - create marker to simplify job output review
//*   UNLOAD   - (conditional) copy to sequential data set
//*   GIMDTS   - (conditional) convert to FB80
//*   LINES    - count lines
//* ENDIF
//*   
//* limit to 63 calls per JCL to avoid hitting JCL EXEC PGM limit (255)
//*   
//*--------
//PTF@     PROC HLQ=&HLQ,                 * work HLQ
//            REL=&REL,                   * hlq.F1, hlq.F2, ...
//            MBR=&MBR,                   * member name Fx(<member>)
//            SYSOUT=&SYSOUT,             * dataset collecting SYSPRINT
//            LINES=&LINES,               * dataset collecting line cnt
//            DSP='DELETE',               * final DISP of temp files
//            SIZE='TRK,(#trks)',        * temp file size
//* enable/disable a step
//            UNLOAD=IEFBR14,             * IEFBR14 (skip) or IKJEFT01
//            GIMDTS=IEFBR14,             * IEFBR14 (skip) or GIMDTS
//* tools invoked in steps (override possible for debug purposes)
//            XMRK=RXDDALOC,              * REXX to allocate marker DD
//            XSEQ=RXUNLOAD,              * REXX to create SEQ
//            XCNT=RXLINES,               * REXX to count lines
//            TOOL=&TOOL                  * DSN holding REXX
//* DDs altered by caller
//*UNLOAD.SYSUT1 DD DUMMY                 * PROVIDED BY CALLER
//*UNLOAD.SYSUT2 DD DDNAME=UNLOAD         * OVERRIDE IF WRITE TO 'PART'
//*GIMDTS.SYSUT1 DD DSN=&$UNLOAD          * OVERRIDE IF NOT FROM UNLOAD
//*
//* limit fixed MLQ to max 2 char to allow 32 chars for HLQ
//* SMP/E part in seq FB80 format   * KEEP IN SYNC WITH smpe-service.sh
//         SET $PART=&HLQ..#mlq.&MBR
//* temp file, LMOD/member -> sequential
//         SET $UNLOAD=&HLQ..$U.&MBR
//* temp files, staging for converting LMOD, set by PTF@LMOD
//*        SET $PDSE=&HLQ..$E.&MBR
//*        SET $PDS=&HLQ..$P.&MBR
//*
//* skip whole proc if needed
//*
//         IF (RC <= 4) THEN
//*
//* create marker DD, and allocate work files
//* on failure marker DD shows which file (&MBR) was being processed
//*
//MARKER   EXEC PGM=IKJEFT01,REGION=0M,COND=(4,LT),
//            PARM='%&XMRK &MBR'
//SYSPROC  DD DISP=SHR,DSN=&TOOL
//SYSTSPRT DD DISP=MOD,DSN=&SYSOUT
//SYSTSIN  DD DUMMY
//* allocate work data sets
//UNLOAD   DD DISP=(NEW,CATLG),SPACE=(&SIZE,RLSE),UNIT=SYSALLDA,
#volser
//            LIKE=&REL,DCB=(DSORG=PS),DSN=&$UNLOAD
//* no DD PDSE only used for LMOD, created by PTF@LMOD
//*PDSE     DD DISP=(NEW,CATLG),SPACE=(&SIZE,RLSE),UNIT=SYSALLDA,
//*            LIKE=&REL,DSNTYPE=LIBRARY,LRECL=0,DSN=&$PDSE
//*
//* unload file (LMOD, member) to sequential
//* ALIAS info is pulled from MCS
//*
//UNLOAD   EXEC PGM=&UNLOAD,REGION=0M,COND=(4,LT),
//            PARM='%&XSEQ &MBR'
//SYSPROC  DD DISP=SHR,DSN=&TOOL
//SYSTSPRT DD DISP=MOD,DSN=&SYSOUT
//SYSTSIN  DD DUMMY
//SYSUT1   DD DUMMY                       * PROVIDED BY CALLER
//SYSUT2   DD DDNAME=UNLOAD               * OPTIONAL OVERRIDE CALLER
//UNLOAD   DD DISP=OLD,DSN=&$UNLOAD       * SYSUT2 option
//PART     DD DISP=MOD,DSN=&$PART         * SYSUT2 option
//MCS      DD DISP=SHR,DSN=&$PART
//* PDSE & PDS are work files for converting LMOD, added by PTF@LMOD
//*PDSE DD DISP=OLD,DSN=&$PDSE
//* Marist requires $PDS and $PDSE are allocated in different steps
//*PDS      DD DISP=(NEW,CATLG),UNIT=SYSALLDA,LIKE=&$PDSE,DSN=&$PDS,
//*            SPACE=(,(,,5)),DSNTYPE=PDS,LRECL=0   * LRECL=0 mandatory
//*
//* convert unloaded file to FB80 & save in &$PART
//*
//GIMDTS   EXEC PGM=&GIMDTS,REGION=0M,COND=(4,LT)
//*STEPLIB  DD DISP=SHR,DSN=SYS1.MIGLIB
//SYSPRINT DD DISP=MOD,DSN=&SYSOUT
//SYSUT1   DD DISP=OLD,DSN=&$UNLOAD       * OPTIONAL OVERRIDE CALLER
//SYSUT2   DD DISP=MOD,DSN=&$PART
//*  GIMDTS:
//*    SYSUT1 data set or member to be converted
//*           RECFM must be: F, FA, FM, FB, FBA, FBM, V, VA, VM,
//*           VB, VBA OR VBM (no spanned records allowed)
//*    SYSUT2 data set or member that will contain the transformed
//*           data, RECFM = FB, LRECL = 80, BLKSIZE = (multiple of 80)
//*    SYSPRINT must be RECFM = FBA, LRECL = 121
//*
//* count lines & process final disposition of work files
//*
//LINES    EXEC PGM=IKJEFT01,REGION=0M,COND=(4,LT),
//            PARM='%&XCNT &MBR'
//SYSPROC  DD DISP=SHR,DSN=&TOOL
//SYSTSPRT DD DISP=MOD,DSN=&SYSOUT
//SYSTSIN  DD DUMMY
//SYSUT1   DD DISP=SHR,DSN=&$PART
//* set disposition ow work data sets
//UNLOAD   DD DISP=(OLD,&DSP),DSN=&$UNLOAD
//SYSPRINT DD DISP=MOD,DSN=&LINES
//* added by PTF@LMOD
//*PDSE     DD DISP=(OLD,&DSP),DSN=&$PDSE
//*PDS      DD DISP=(OLD,&DSP),DSN=&$PDS
//*
//         ENDIF (RC <= 4)
//*
//         PEND
//*--------
//*
