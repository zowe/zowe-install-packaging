//ZWE6DDEF JOB <job parameters>
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
//* This JCL will create DDDEF entries for product
//* Zowe Open Source Project
//*
//*
//* CAUTIONS:
//* A) This job contains case sensitive path statements.
//* B) This is neither a JCL procedure nor a complete job.
//*    Before using this JCL, you will have to make the following
//*    modifications:
//*
//* 1) Add the job parameters to meet your system requirements.
//*
//* 2) Change #csihlq to the high level qualifier for the global zone
//*    of the CSI.
//*
//* 3) Change #tzone to your CSI target zone name.
//*
//* 4) Change #dzone to your CSI distribution zone name.
//*
//* 5) Change #thlq to the appropriate high level qualifier(s) for
//*    the target data sets, as used in the ZWE3ALOC job.
//*
//* 6) Change #dhlq to the appropriate high level qualifier(s) for
//*    the distribution data sets, as used in the ZWE3ALOC job.
//*
//* 7) If you opted in job ZWE3ALOC to use non-cataloged target
//*    data sets;
//*    a) Uncomment all VOLUME(&TVOL) statements.
//*    b) Change #tvol to the volser of the target volume,
//*       as used in the ZWE3ALOC job.
//*
//* 8) If you opted in job ZWE3ALOC to use non-cataloged distribution
//*    data sets;
//*    a) Uncomment all VOLUME(&DVOL) statements.
//*    b) Change #dvol to the volser of the distribution volume,
//*       as used in the ZWE3ALOC job.
//*
//* 9) Change the string "-PathPrefix-" in step DEFPATH to the
//*    high-level directory name, as used in job ZWE5MKD.
//*
//*    Please note that the replacement string is case sensitive.
//*
//* Note(s):
//*
//* 1. If you specify a volume for any data set in this job, you
//*    must also specify the same volume in the corresponding
//*    data set allocation job, ZWE3ALOC.
//*
//* 2. Ensure that -PathPrefix- is an absolute path name and begins
//*    and ends with a slash (/).
//*
//* 3. Run only the steps that are applicable to your installation.
//*
//* 4. This job should complete with a return code 0.
//*    If some or all of these DDDEF entries already exist, then the
//*    job will complete with a return code 8.
//*    You will have to examine the output and determine wether or
//*    not the existing entries should be replaced.
//*    You can change the 'ADD' to 'REP' in this job to replace
//*    existing entries.
//*
//*    You may receive the following message for the first change
//*    command in the DEFPATH step. This message is expected and
//*    can be ignored:
//*      GIM26501W     THE PATH SUBENTRY WAS NOT CHANGED.
//*    If you receive this message, a return code of 4 is expected
//*    for the DEFPATH step.
//*
//********************************************************************
//         EXPORT SYMLIST=(TZONE,DZONE,THLQ,DHLQ,TVOL,DVOL)
//*
//         SET CSIHLQ=#csihlq
//         SET TZONE=#tzone
//         SET DZONE=#dzone
//         SET THLQ=#thlq
//         SET DHLQ=#dhlq
//         SET TVOL=#tvol
//         SET DVOL=#dvol
//*
//* DDDEFs FOR TARGET ZONE
//*
//DDDEFTGT EXEC PGM=GIMSMP,REGION=0M,COND=(4,LT)
//SMPCSI   DD DISP=OLD,DSN=&CSIHLQ..CSI
//SMPCNTL  DD *,SYMBOLS=JCLONLY
  SET   BDY(&TZONE) .
  UCLIN .
    ADD DDDEF (SZWEAUTH)
        DATASET(&THLQ..SZWEAUTH)
        UNIT(SYSALLDA)
     /* VOLUME(&TVOL) */
        WAITFORDSN
        SHR .
    ADD DDDEF (SZWESAMP)
        DATASET(&THLQ..SZWESAMP)
        UNIT(SYSALLDA)
     /* VOLUME(&TVOL) */
        WAITFORDSN
        SHR .
    ADD DDDEF (SZWEZFS)
     /* do NOT alter PATH, correction is done in step DEFPATH */
        PATH('/usr/lpp/zowe/SMPE/') .
    ADD DDDEF (AZWEAUTH)
        DATASET(&DHLQ..AZWEAUTH)
        UNIT(SYSALLDA)
     /* VOLUME(&DVOL) */
        WAITFORDSN
        SHR .
    ADD DDDEF (AZWESAMP)
        DATASET(&DHLQ..AZWESAMP)
        UNIT(SYSALLDA)
     /* VOLUME(&DVOL) */
        WAITFORDSN
        SHR .
    ADD DDDEF (AZWEZFS)
        DATASET(&DHLQ..AZWEZFS)
        UNIT(SYSALLDA)
     /* VOLUME(&DVOL) */
        WAITFORDSN
        SHR .
  ENDUCL .
//*
//* DDDEFs FOR DISTRIBUTION ZONE
//*
//DDDEFDLB EXEC PGM=GIMSMP,REGION=0M,COND=(4,LT)
//SMPCSI   DD DISP=OLD,DSN=&CSIHLQ..CSI
//SMPCNTL  DD *,SYMBOLS=JCLONLY
  SET   BDY(&DZONE) .
  UCLIN .
    ADD DDDEF (AZWEAUTH)
        DATASET(&DHLQ..AZWEAUTH)
        UNIT(SYSALLDA)
     /* VOLUME(&DVOL) */
        WAITFORDSN
        SHR .
    ADD DDDEF (AZWESAMP)
        DATASET(&DHLQ..AZWESAMP)
        UNIT(SYSALLDA)
     /* VOLUME(&DVOL) */
        WAITFORDSN
        SHR .
    ADD DDDEF (AZWEZFS)
        DATASET(&DHLQ..AZWEZFS)
        UNIT(SYSALLDA)
     /* VOLUME(&DVOL) */
        WAITFORDSN
        SHR .
  ENDUCL .
//*
//*  Change the string "-PathPrefix-" to the appropriate
//*  high level directory name. For users installing in the root,
//*  this would be "/". For others, the high level directory may
//*  be something like "/service/", or a more meaningful name.
//*
//*  "-PathPrefix-" must match the value used in job ZWE5MKD.
//*
//*  Verify that the changed path statement does not contain
//*  double slashes (such as //usr/lpp) prior to running this step.
//*
//DEFPATH  EXEC PGM=GIMSMP,REGION=0M,COND=(4,LT)
//SMPCSI   DD DISP=OLD,DSN=&CSIHLQ..CSI
//SMPCNTL  DD *,SYMBOLS=JCLONLY
  SET BDY(&TZONE) .        /* do NOT change "PATH('/usr/lpp/zowe'*," */
  ZONEEDIT DDDEF .         /* only change the 2nd (PathPrefix) line  */
    CHANGE PATH('/usr/lpp/zowe'*,
     '-PathPrefix-usr/lpp/zowe'*) .
  ENDZONEEDIT .
//*
