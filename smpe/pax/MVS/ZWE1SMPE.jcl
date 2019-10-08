//ZWE1SMPE JOB <job parameters>
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
//*********************************************************************
//*
//* This JCL allocates and primes a CSI, allocates data sets required
//* by SMP/E and defines DDDEFs required by SMP/E for product
//* Zowe Open Source Project
//*
//*
//* CAUTION: This is neither a JCL procedure nor a complete job.
//* Before using this job step, you will have to make the following
//* modifications:
//*
//* 1) Add the job parameters to meet your system requirements.
//*
//* 2) Change #csihlq to the high level qualifier for the CSI and
//*    other SMP/E data sets. The maximum length is 26 characters.
//*
//* 3) Change #tzone to your CSI target zone name.
//*
//* 4) Change #dzone to your CSI distribution zone name.
//*
//* 5) Change #csivol to the volser for the CSI and SMP/E data sets,
//*    if you choose not to use the default of letting your Automatic
//*    Class Selection (ACS) routines decide which volume to use.
//*    If you use #csivol, also uncomment all references to variable
//*    &CSIVOL:
//*    - VOLUMES(&CSIVOL) in step DEFCSI
//*    - VOL=SER=&CSIVOL in multiple DDs of step ZONING
//*
//* 6) This product can install in multiple SREL subsystems;
//*    Z038 (z/OS), P115 (IMS/DB2), and C150 (CICS). Update the
//*    SET SREL= statement to select the desired SREL.
//*
//* Note(s):
//*
//* 1. JES3 configurations do not allow creation and usage of a
//*    data set in the same JCL, and fail the job on the INITCSI
//*    step with an invalid data set name error. If you are running
//*    in a JES3 environment, split this job into 2 jobs at the
//*    "--SPLIT HERE IF NEEDED --" marker and submit them seperatly.
//*
//* 2. This job uses PDSE data sets. If required, you can comment out
//*    all occurances of DSNTYPE=LIBRARY to use PDS datasets instead.
//*
//* 3. This job should complete with a return code 0.
//*
//*********************************************************************
//         EXPORT SYMLIST=(CSIHLQ,CSIVOL,TZONE,DZONE,SREL,DSPREFIX)
//*                            1         2
//*                   12345678901234567890123456   DSPREFIX limit
//         SET CSIHLQ=#csihlq
//         SET TZONE=#tzone
//         SET DZONE=#dzone
//         SET CSIVOL=#csivol
//         SET SREL=Z038     # Z038 (z/OS), P115 (IMS/DB2), C150 (CICS)
//*
//         SET DSPREFIX=&CSIHLQ          # HLQ for SMP/E work data sets
//*
//* ALLOCATE CSI
//*
//DEFCSI   EXEC PGM=IDCAMS,REGION=0M,COND=(4,LT)
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *,SYMBOLS=JCLONLY
  DEFINE CLUSTER(             -
    NAME(&CSIHLQ..CSI)        -
  /*VOLUMES(&CSIVOL)*/        -
    RECORDSIZE(24 143)        -
    KEYS(24 0)                -
    FREESPACE(10,5)           -
    SHR(2)                    -
    UNIQUE                    -
    IMBED)                    -
         DATA(                -
    NAME(&CSIHLQ..CSI.DATA)   -
    CONTROLINTERVALSIZE(4096) -
    CYLINDERS(10 5))          -
         INDEX(               -
    NAME(&CSIHLQ..CSI.INDEX)  -
    CYLINDERS(1 1))
//*
//* -- SPLIT HERE IF NEEDED --
//*
//* PRIME CSI
//*
//INITCSI  EXEC PGM=IDCAMS,REGION=0M,COND=(4,LT)
//SMPCSI   DD DISP=OLD,DSN=&CSIHLQ..CSI
//ZPOOL    DD DISP=SHR,DSN=SYS1.MACLIB(GIMZPOOL)
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
  REPRO INFILE(ZPOOL) OUTFILE(SMPCSI)
//*
//* ALLOCATE SMP/E WORK DATA SETS
//* DEFINE TARGET & DISTRIBUTION ZONES, OPTIONS, UTILITIES AND DDDEFS
//*
//ZONING   EXEC PGM=GIMSMP,REGION=0M,COND=(4,LT)
//SMPCSI   DD DISP=OLD,DSN=&CSIHLQ..CSI
//*
//SMPLOG   DD DSN=&DSPREFIX..SMPLOG,
//            DISP=(NEW,CATLG,DELETE),
//            DSORG=PS,
//            RECFM=VB,
//            LRECL=3200,
//            BLKSIZE=0,
//            UNIT=SYSALLDA,
//*           VOL=SER=&CSIVOL,
//            SPACE=(TRK,(30,15))
//*
//SMPLOGA  DD DSN=&DSPREFIX..SMPLOGA,
//            DISP=(NEW,CATLG,DELETE),
//            DSORG=PS,
//            RECFM=VB,
//            LRECL=3200,
//            BLKSIZE=0,
//            UNIT=SYSALLDA,
//*           VOL=SER=&CSIVOL,
//            SPACE=(TRK,(30,15))
//*
//SMPLTS   DD DSN=&DSPREFIX..SMPLTS,
//            DISP=(NEW,CATLG,DELETE),
//            DSNTYPE=LIBRARY,
//            RECFM=U,
//            LRECL=0,
//            BLKSIZE=32760,
//            UNIT=SYSALLDA,
//*           VOL=SER=&CSIVOL,
//            SPACE=(TRK,(30,30,80))
//*
//SMPMTS   DD DSN=&DSPREFIX..SMPMTS,
//            DISP=(NEW,CATLG,DELETE),
//            DSORG=PO,
//            RECFM=FB,
//            LRECL=80,
//            BLKSIZE=0,
//            UNIT=SYSALLDA,
//*           VOL=SER=&CSIVOL,
//            DSNTYPE=LIBRARY,
//            SPACE=(TRK,(10,5,80))
//*
//SMPPTS   DD DSN=&DSPREFIX..SMPPTS,
//            DISP=(NEW,CATLG,DELETE),
//            DSORG=PO,
//            RECFM=FB,
//            LRECL=80,
//            BLKSIZE=0,
//            UNIT=SYSALLDA,
//*           VOL=SER=&CSIVOL,
//            DSNTYPE=LIBRARY,
//            SPACE=(TRK,(12000,3000,80))
//*
//SMPSCDS  DD DSN=&DSPREFIX..SMPSCDS,
//            DISP=(NEW,CATLG,DELETE),
//            DSORG=PO,
//            RECFM=FB,
//            LRECL=80,
//            BLKSIZE=0,
//            UNIT=SYSALLDA,
//*           VOL=SER=&CSIVOL,
//            DSNTYPE=LIBRARY,
//            SPACE=(TRK,(10,5,80))
//*
//SMPSTS   DD DSN=&DSPREFIX..SMPSTS,
//            DISP=(NEW,CATLG,DELETE),
//            DSORG=PO,
//            RECFM=FB,
//            LRECL=80,
//            BLKSIZE=0,
//            UNIT=SYSALLDA,
//*           VOL=SER=&CSIVOL,
//            DSNTYPE=LIBRARY,
//            SPACE=(TRK,(10,5,80))
//*
//SMPLIST  DD SYSOUT=*
//SYSPRINT DD SYSOUT=*
//SMPOUT   DD SYSOUT=*
//SMPRPT   DD SYSOUT=*
//SMPSNAP  DD SYSOUT=*
//SMPWRK1  DD UNIT=SYSALLDA,SPACE=(CYL,(2,1,10)),RECFM=FB,LRECL=80
//SMPWRK2  DD UNIT=SYSALLDA,SPACE=(CYL,(2,1,10)),RECFM=FB,LRECL=80
//SMPWRK3  DD UNIT=SYSALLDA,SPACE=(CYL,(2,1,10)),RECFM=FB,LRECL=80
//SMPWRK4  DD UNIT=SYSALLDA,SPACE=(CYL,(2,1,10)),RECFM=FB,LRECL=80
//SMPWRK6  DD UNIT=SYSALLDA,SPACE=(CYL,(20,200,50)),RECFM=FB,LRECL=80
//SYSUT1   DD UNIT=SYSALLDA,SPACE=(CYL,(20,200))
//SYSUT2   DD UNIT=SYSALLDA,SPACE=(CYL,(2,1))
//SYSUT3   DD UNIT=SYSALLDA,SPACE=(CYL,(2,1))
//SYSUT4   DD UNIT=SYSALLDA,SPACE=(CYL,(2,1))
//SMPCNTL  DD *,SYMBOLS=JCLONLY
  SET   BDY(GLOBAL) .           /* SET TO GLOBAL ZONE         */
  UCLIN.
    ADD GLOBALZONE              /* DEFINE GLOBAL ZONE NOW     */
        OPTIONS(ESAOPT)         /* DEFINE AN OPTIONS ENTRY    */
        SREL(&SREL.)            /* z/OS, CICS, OR IMS/DB2     */
        ZONEINDEX(              /* ZONES TO BE SET UP         */
          (&TZONE,&CSIHLQ..CSI,TARGET),
          (&DZONE,&CSIHLQ..CSI,DLIB))
        .
    ADD OPTIONS(ESAOPT)         /* ADD AN OPTIONS ENTRY       */
        ASM(ASMUTIL)            /* SMP ASSEMBLER UTILITY NAME */
        LKED(LINKEDIT)          /* SMP LINK EDIT UTILITY NAME */
        DSPREFIX(&DSPREFIX.)    /* HLQ FOR RECIEVED DATA      */
        DSSPACE(1200,1200,1400) /* SPACE FOR TLIB DATA SETS   */
      /*NOPURGE*/               /* KEEP SYSMOD AFTER APPLY    */
        .
    ADD UTILITY(ASMUTIL)        /* ASSEMBLER UTILITY ENTRY    */
        NAME(ASMA90)            /* ASMA90 IS ASSEMBLER H      */
        RC(4)                   /* RETURN CODE THRESHOLD      */
        PARM(DECK,NOOBJECT,USING(WARN(2)))
        .
    ADD UTILITY(LINKEDIT)       /* LINK EDIT UTILITY ENTRY    */
        NAME(IEWL)              /* NAME OF LINKAGE EDITOR     */
        RC(4)                   /* RETURN CODE THRESHOLD      */
        PRINT(SYSPRINT)         /* DDNAME FOR SYSPRINT OUTPUT */
        PARM(SIZE=(1526K,100K),NCAL,LET,LIST,XREF)
        .
    ADD DDDEF(SMPOUT)   SYSOUT(*) .
    ADD DDDEF(SMPRPT)   SYSOUT(*) .
    ADD DDDEF(SMPLIST)  SYSOUT(*) .
    ADD DDDEF(SYSPRINT) SYSOUT(*) .
    ADD DDDEF(SMPSNAP)  SYSOUT(*) .
    ADD DDDEF(SMPTLIB)  UNIT(SYSALLDA) .
    ADD DDDEF(SYSUT1)   CYL SPACE(20,200) UNIT(SYSALLDA) .
    ADD DDDEF(SYSUT2)   CYL SPACE(2,1) UNIT(SYSALLDA) .
    ADD DDDEF(SYSUT3)   CYL SPACE(2,1) UNIT(SYSALLDA) .
    ADD DDDEF(SYSUT4)   CYL SPACE(2,1) UNIT(SYSALLDA) .
    ADD DDDEF(SMPTLOAD) CYL SPACE(2,1) DIR(10) UNIT(SYSALLDA) .
    ADD DDDEF(SMPLOG)   DA(&DSPREFIX..SMPLOG) MOD .
    ADD DDDEF(SMPLOGA)  DA(&DSPREFIX..SMPLOGA) MOD .
    ADD DDDEF(SMPLTS)   DA(&DSPREFIX..SMPLTS) SHR .
    ADD DDDEF(SMPMTS)   DA(&DSPREFIX..SMPMTS) SHR .
    ADD DDDEF(SMPPTS)   DA(&DSPREFIX..SMPPTS) SHR .
    ADD DDDEF(SMPSCDS)  DA(&DSPREFIX..SMPSCDS) SHR .
    ADD DDDEF(SMPSTS)   DA(&DSPREFIX..SMPSTS) SHR .
  ENDUCL .
  SET   BDY(&TZONE) .           /* SET TO TARGET ZONE         */
  UCLIN.
    ADD TARGETZONE(&TZONE)      /* DEFINE TARGET ZONE         */
        RELATED(&DZONE)         /* DISTRIBUTION LIBRARY       */
        OPTIONS(ESAOPT)         /* DEFINE AN OPTIONS ENTRY    */
        SREL(&SREL.)            /* z/OS, CICS, OR IMS/DB2     */
        .                       /*                            */
    ADD DDDEF(SMPOUT)   SYSOUT(*) .
    ADD DDDEF(SMPRPT)   SYSOUT(*) .
    ADD DDDEF(SMPLIST)  SYSOUT(*) .
    ADD DDDEF(SYSPRINT) SYSOUT(*) .
    ADD DDDEF(SMPSNAP)  SYSOUT(*) .
    ADD DDDEF(SYSUT1)   CYL SPACE(20,200) UNIT(SYSALLDA) .
    ADD DDDEF(SYSUT2)   CYL SPACE(2,1) UNIT(SYSALLDA) .
    ADD DDDEF(SYSUT3)   CYL SPACE(2,1) UNIT(SYSALLDA) .
    ADD DDDEF(SYSUT4)   CYL SPACE(2,1) UNIT(SYSALLDA) .
    ADD DDDEF(SMPLOG)   DA(&DSPREFIX..SMPLOG) MOD .
    ADD DDDEF(SMPLOGA)  DA(&DSPREFIX..SMPLOGA) MOD .
    ADD DDDEF(SMPLTS)   DA(&DSPREFIX..SMPLTS) SHR .
    ADD DDDEF(SMPMTS)   DA(&DSPREFIX..SMPMTS) SHR .
    ADD DDDEF(SMPPTS)   DA(&DSPREFIX..SMPPTS) SHR .
    ADD DDDEF(SMPSCDS)  DA(&DSPREFIX..SMPSCDS) SHR .
    ADD DDDEF(SMPSTS)   DA(&DSPREFIX..SMPSTS) SHR .
    ADD DDDEF(SYSLIB)   CONCAT(SMPMTS) .
    ADD DDDEF(SMPTLOAD) CYL SPACE(2,1) DIR(10) UNIT(SYSALLDA) .
    ADD DDDEF(SMPWRK1)  CYL SPACE(2,1) DIR(10) UNIT(SYSALLDA) .
    ADD DDDEF(SMPWRK2)  CYL SPACE(2,1) DIR(10) UNIT(SYSALLDA) .
    ADD DDDEF(SMPWRK3)  CYL SPACE(2,1) DIR(10) UNIT(SYSALLDA) .
    ADD DDDEF(SMPWRK4)  CYL SPACE(2,1) DIR(10) UNIT(SYSALLDA) .
    ADD DDDEF(SMPWRK6)  CYL SPACE(20,200) DIR(50) UNIT(SYSALLDA) .
  ENDUCL .
  SET   BDY(&DZONE) .           /* SET TO DISTRIBUTION ZONE   */
  UCLIN.
    ADD DLIBZONE(&DZONE)        /* DEFINE DISTRIBUTION ZONE   */
        RELATED(&TZONE)         /* TARGET LIBRARY             */
        OPTIONS(ESAOPT)         /* DEFINE AN OPTIONS ENTRY    */
        SREL(&SREL.)            /* z/OS, CICS, OR IMS/DB2     */
        .
    ADD DDDEF(SMPOUT)   SYSOUT(*) .
    ADD DDDEF(SMPRPT)   SYSOUT(*) .
    ADD DDDEF(SMPLIST)  SYSOUT(*) .
    ADD DDDEF(SYSPRINT) SYSOUT(*) .
    ADD DDDEF(SMPSNAP)  SYSOUT(*) .
    ADD DDDEF(SYSUT1)   CYL SPACE(20,200) UNIT(SYSALLDA) .
    ADD DDDEF(SYSUT2)   CYL SPACE(2,1) UNIT(SYSALLDA) .
    ADD DDDEF(SYSUT3)   CYL SPACE(2,1) UNIT(SYSALLDA) .
    ADD DDDEF(SYSUT4)   CYL SPACE(2,1) UNIT(SYSALLDA) .
    ADD DDDEF(SMPLOG)   DA(&DSPREFIX..SMPLOG) MOD .
    ADD DDDEF(SMPLOGA)  DA(&DSPREFIX..SMPLOGA) MOD .
    ADD DDDEF(SMPLTS)   DA(&DSPREFIX..SMPLTS) SHR .
    ADD DDDEF(SMPMTS)   DA(&DSPREFIX..SMPMTS) SHR .
    ADD DDDEF(SMPPTS)   DA(&DSPREFIX..SMPPTS) SHR .
    ADD DDDEF(SMPSCDS)  DA(&DSPREFIX..SMPSCDS) SHR .
    ADD DDDEF(SMPSTS)   DA(&DSPREFIX..SMPSTS) SHR .
    ADD DDDEF(SYSLIB)   CONCAT(SMPMTS) .
    ADD DDDEF(SMPTLOAD) CYL SPACE(2,1) DIR(10) UNIT(SYSALLDA) .
    ADD DDDEF(SMPWRK1)  CYL SPACE(2,1) DIR(10) UNIT(SYSALLDA) .
    ADD DDDEF(SMPWRK2)  CYL SPACE(2,1) DIR(10) UNIT(SYSALLDA) .
    ADD DDDEF(SMPWRK3)  CYL SPACE(2,1) DIR(10) UNIT(SYSALLDA) .
    ADD DDDEF(SMPWRK4)  CYL SPACE(2,1) DIR(10) UNIT(SYSALLDA) .
    ADD DDDEF(SMPWRK6)  CYL SPACE(20,200) DIR(50) UNIT(SYSALLDA) .
  ENDUCL .
  LIST ALLZONES .                /* LIST ZONE INFORMATION      */
//*
