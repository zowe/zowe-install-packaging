//GIMDTS   JOB #job1
//* This program and the accompanying materials are made available
//* under the terms of the Eclipse Public License v2.0 which
//* accompanies this distribution, and is available at
//* https://www.eclipse.org/legal/epl-v20.html
//*
//* SPDX-License-Identifier: EPL-2.0
//*
//* Copyright Contributors to the Zowe Project. 2019, 2019
//*********************************************************************
//* Job to create Zowe PTF/APAR/USERMOD parts in GIMDTS format
//* Assumes submitter cleaned &HLQ.** and only these data sets exist:
//* - input, JCL procedures & REXX tools
//*   #hlq
//* - output, parts in FB80 format
//*   #hlq.#mlq.*
//* - output, line count for each #hlq.#mlq.*
//*   #lines
//* - output, job log
//*   #sysprint
//*********************************************************************
//* Depends on JES initialization parameters and JCL error message,
//* these values may need to be adjusted for a successful build:
//* - LINES EXCEEDED by checking $D ESTLNCT
//*   RESPONSE=S0W1      $HASP845 ESTLNCT  NUM=5,INT=5000,OPT=1 
/*JOBPARM LINES=50000
//* - BYTES EXCEEDED by checking $D ESTBYTE
//*   RESPONSE=S0W1      $HASP845 ESTBYTE  NUM=99999,INT=99999,OPT=0 
/*JOBPARM BYTES=9999999
//* - PAGES EXCEEDED by checking $D ESTPAGE
//*   RESPONSE=S0W1      $HASP845 ESTPAGE  NUM=40,INT=10,OPT=0 
//*JOBPARM PAGES=100
//* - CARDS EXCEEDED by checking $D ESTPUN
//*   RESPONSE=S0W1      $HASP845 ESTPUN  NUM=1,INT=1000,OPT=0 
//*JOBPARM CARDS=5000
//*********************************************************************
//*
//*        ----+----1----+----2----+----3--
// SET HLQ=#hlq
// SET LINES=#lines
// SET SYSOUT=#sysprint
// SET TOOL=&HLQ
// JCLLIB ORDER=&TOOL
//*
//* added by submitter
//*        SET REL=#rel
//*#member EXEC PROC=PTF@LMOD,MBR=#member
//*#member EXEC PROC=PTF@FB80,MBR=#member
//*#member EXEC PROC=PTF@MVS,MBR=#member
//*
