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
//*********************************************************************
//*
//*         ----+----1----+----2----+----3----+----4----+----5----+---
// SET MCS='#dir' 
// SET HLQ=#hlq
//*        ----+----1----+----2----+----3--
// SET TOOL=&HLQ
// JCLLIB ORDER=&TOOL
//*
//* to add by caller
//*        SET REL=#rel
//*#member EXEC PROC=PTF@LMOD,MVS=#member
//*#member EXEC PROC=PTF@FB80,MVS=#member
//*#member EXEC PROC=PTF@MVS,MVS=#member
//*
