//GIMMERGE JOB #job1
//* This program and the accompanying materials are made available
//* under the terms of the Eclipse Public License v2.0 which
//* accompanies this distribution, and is available at
//* https://www.eclipse.org/legal/epl-v20.html
//*
//* SPDX-License-Identifier: EPL-2.0
//*
//* Copyright Contributors to the Zowe Project. 2019, 2019
//*********************************************************************
//* Job to merge Zowe parts in a PTF/APAR/USERMOD
//* Assumes submitter ensured these data sets exist:
//* - input, JCL procedures & REXX tools
//*   #hlq
//* - input, parts in FB80 format
//*   #hlq.#mlq.*
//* - output, sysmod
//*   #hlq.#mlq
//* - output, sysmod track count
//*   #tracks
//* - output, job log
//*   #sysprint
//*********************************************************************
//*
//* #comment
//*
//*        ----+----1----+----2----+----3--
// SET HLQ=#hlq
// SET SYSMOD=#sysmod
// SET TRACKS=#tracks
// SET SYSOUT=#sysprint
// SET TOOL=&HLQ
// JCLLIB ORDER=&TOOL
//*
//* added by submitter
//*#member EXEC PROC=PTFMERGE,PART=#part
//*TRACKS  EXEC PROC=PTFTRKS,PTF=#name
//*
