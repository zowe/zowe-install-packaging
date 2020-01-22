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
//* PROC to get tracks used by a data set
//*
//* limit to 255 calls per JCL to avoid hitting JCL EXEC PGM limit (255)
//*
//*--------
//PTFTRKS  PROC PTF=,                     * name of PTF in dataset
//            SYSMOD=&SYSMOD,             * dataset to examine
//            SYSOUT=&SYSOUT,             * dataset collecting SYSPRINT
//            TRACKS=&TRACKS,             * dataset collecting trk cnt
//* tools invoked in steps (override possible for debug purposes)
//            XTRK=RXTRACKS,              * REXX to get track count
//            TOOL=&TOOL                  * DSN holding REXX
//*
//* get tracks used
//*
//TRACKS   EXEC PGM=IKJEFT01,REGION=0M,COND=(4,LT),
//            PARM='%&XTRK &PTF'
//SYSPROC  DD DISP=SHR,DSN=&TOOL
//SYSTSPRT DD DISP=MOD,DSN=&SYSOUT
//SYSTSIN  DD DUMMY
//SYSUT1   DD DISP=SHR,DSN=&SYSMOD
//SYSPRINT DD DISP=MOD,DSN=&TRACKS
//*
//         PEND
//*--------
//*
