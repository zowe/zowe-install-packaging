//GIMZIP   JOB #job1
//* This program and the accompanying materials are made available
//* under the terms of the Eclipse Public License v2.0 which
//* accompanies this distribution, and is available at
//* https://www.eclipse.org/legal/epl-v20.html
//*
//* SPDX-License-Identifier: EPL-2.0
//*
//* Copyright Contributors to the Zowe Project. 2019, 2019
//*********************************************************************
//* Job to create Zowe archive in GIMZIP format
//*********************************************************************
//*         ----+----1----+----2----+----3----+----4----+----5----+---
// SET DIR='#dir' 
// SET HLQ=#hlq
//*        ----+----1----+----2----+----3----+
//GIMZIP   EXEC PGM=GIMZIP,REGION=0M,COND=(0,LT),
// PARM='#parm'
//*STEPLIB  DD DISP=SHR,DSN=SYS1.MIGLIB
//SYSUT2   DD UNIT=SYSALLDA,
#volser
//            SPACE=(CYL,(200,100))
//SYSUT3   DD UNIT=SYSALLDA,SPACE=(CYL,(50,10))
//SYSUT4   DD UNIT=SYSALLDA,SPACE=(CYL,(25,5))
//SMPOUT   DD DISP=SHR,DSN=&HLQ..SMPOUT
//SYSPRINT DD DISP=MOD,DSN=&HLQ..SYSPRINT
//* package control tags
//SYSIN    DD DISP=SHR,DSN=&HLQ..SYSIN       
//* package directory
//SMPDIR   DD PATHDISP=KEEP,PATH='&DIR/SMPDIR'    
//* smp classes directory
//SMPCPATH DD PATHDISP=KEEP,PATH='&DIR/SMPCPATH'  
//* java runtime directory
//SMPJHOME DD PATHDISP=KEEP,PATH='&DIR/SMPJHOME'  
//* optional work directory, default use SMPDIR for temp files
//*SMPWKDIR DD PATH='&DIR/SMPWKDIR',
//*            PATHOPTS=(OWRONLY,OCREAT,OTRUNC), 
//*            PATHMODE=SIRWXU                   
//*
