//ZWECSVSM JOB
//*
//* This program and the accompanying materials are made available
//* under the terms of the Eclipse Public License v2.0 which
//* accompanies this distribution, and is available at
//* https://www.eclipse.org/legal/epl-v20.html
//*
//* SPDX-License-Identifier: EPL-2.0
//*
//* Copyright Contributors to the Zowe Project. 2020, 2020
//*
//*********************************************************************
//*
//* Zowe Open Source Project
//* This JCL can be used to create VSAM data set for Caching Service.
//*
//* CAUTION: This is neither a JCL procedure nor a complete job.
//* Before using this JCL, you will have to make the following
//* modifications:
//*
//* 1) Add job name and job parameters to the JOB statement, to
//*    meet your system requirements.
//*
//* 2) Change #dsname to the VSAM KSDS data set name.
//*
//* 3) If your installation supports VSAM RLS, you can un-comment
//*    STORCLAS and comment out VOLUME to use your VSAM storage
//*    class. You will need to change #storclas or #volume to
//*    match your settings.
//*
//* 4) If your installation supports VSAM RLS, you should also
//*    un-comment LOG and comment out SHAREOPTIONS. You may want
//*    to change the option of LOG to UNDO or ALL to make VSAM
//*    recoverable or non-recoverable.
//*
//********************************************************************
//S1    EXEC PGM=IDCAMS,REGION=0M
//SYSPRINT DD SYSOUT=*
//SYSIN   DD *
  DEFINE CLUSTER -
    (NAME(#dsname) -
//* STORCLAS(#storclas) -
    VOLUME(#volume) -
    REC(80 20) -
//* LOG(NONE) -
    SHAREOPTIONS(2 3) -
    INDEXED) -
    DATA(NAME(#dsname.DATA) -
     RECSZ(80 4096) -
     UNIQUE -
     KEYS(128 0)) -
    INDEX(NAME(#dsname.INDEX) -
     UNIQUE)
/*
