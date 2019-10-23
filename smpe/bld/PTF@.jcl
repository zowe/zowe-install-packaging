//*
//* PROC to stage file for SYSMOD creation, generic back-end
//*
//* PROC logic:
//* IF (RC <= 4) THEN
//*   MARKER   - create marker to simplify job output review
//*   UNLOAD   - (conditional) copy to sequential data set
//*   GIMDTS   - (conditional) convert to FB80
//*   DISP     - set final disposition
//* ENDIF
//*   
//* Limit to 63 calls per JCL to avoid hitting JCL EXEC PGM limit (255)
//*   
//*--------
//PTF@     PROC HLQ=&HLQ,                 * work HLQ
//*           MCS=&MCS,                   * MCS path, must be inherited
//            REL=&REL,                   * hlq.F1, hlq.F2, ...
//            MVS=&MVS,                   * member name Fx(<member>)
//            SYSOUT=&SYSOUT,             * dataset collecting SYSPRINT
//            DSP='DELETE',               * final DISP of temp files
//            SIZE='CYL,(1,50)',          * temp file size
//* enable/disable a step
//            UNLOAD=IEFBR14,             * IEFBR14 (skip) or IKJEFT01
//            GIMDTS=IEFBR14,             * IEFBR14 (skip) or GIMDTS
//* tools invoked in steps (override possible for debug purposes)
//            XMRK=RXDDALOC,              * REXX to allocate marker DD
//            XSEQ=RXUNLOAD,              * REXX to create SEQ
//            TOOL=&TOOL                  * DSN holding REXX
//* DDs altered by caller
//*UNLOAD.SYSUT1 DD DUMMY                 * PROVIDED BY CALLER
//*UNLOAD.SYSUT2 DD DDNAME=UNLOAD         * OVERRIDE IF WRITE TO OUTPUT
//*GIMDTS.SYSUT1 DD DSN=&$UNLOAD          * OVERRIDE IF NOT FROM UNLOAD
//*
//* limit fixed MLQ to max 2 char to allow 32 chars for HLQ
//* SMP/E part in sequential FB80 format
//         SET $PART=&HLQ..@.&MVS
//* temp file, LMOD/member -> sequential
//         SET $UNLOAD=&HLQ..$U.&MVS
//* temp file, template for converting LMOD, set by PTF@LMOD
//*        SET $COPY=&HLQ..$C.&MVS
//*
//* skip whole proc if needed
//*
//         IF (RC <= 4) THEN
//*
//* create marker DD, and allocate work files
//* on failure marker DD shows which file (&MVS) was being processed
//*
//MARKER   EXEC PGM=IKJEFT01,REGION=0M,COND=(4,LT),
//            PARM='%&XMRK &MVS'
//SYSPROC  DD DISP=SHR,DSN=&TOOL
//SYSTSPRT DD DISP=(MOD,CATLG),SPACE=(&SIZE,RLSE),UNIT=SYSALLDA,
#volser
//            DCB=(DSORG=PS,RECFM=FBA,LRECL=121),DSN=&SYSOUT
//SYSTSIN  DD DUMMY
//* allocate work data sets
//UNLOAD   DD DISP=(NEW,PASS),SPACE=(&SIZE,RLSE),UNIT=SYSALLDA,
#volser
//            LIKE=&REL,DCB=(DSORG=PS),DSN=&$UNLOAD
//PART     DD DISP=(NEW,CATLG),SPACE=(&SIZE,RLSE),UNIT=SYSALLDA,
#volser
//            DCB=(DSORG=PS,RECFM=FB,LRECL=80),DSN=&$PART
//* no DD PDSE, temp file that requires a name, created by PTF@LMOD
//*
//* unload file (LMOD, member) to sequential
//* ALIAS info is pulled from MCS
//*
//UNLOAD   EXEC PGM=&UNLOAD,REGION=0M,COND=(4,LT),
//            PARM='%&XSEQ &MVS'
//SYSPROC  DD DISP=SHR,DSN=&TOOL
//SYSTSPRT DD DISP=MOD,DSN=&SYSOUT
//SYSTSIN  DD DUMMY
//SYSUT1   DD DUMMY                       * PROVIDED BY CALLER
//SYSUT2   DD DDNAME=UNLOAD               * OPTIONAL OVERRIDE CALLER
//UNLOAD   DD DISP=(OLD,PASS),DSN=&$UNLOAD
//PART     DD DISP=OLD,DSN=&$PART
//MCS      DD PATHDISP=KEEP,PATH='&MCS/&MVS'
//* work files for converting LMOD, added by PTF@LMOD
//*PDSE     DD DISP=(NEW,PASS),SPACE=(&SIZE,RLSE),UNIT=SYSALLDA,
//*            LIKE=&REL,DSNTYPE=LIBRARY,LRECL=0,DSN=&$COPY
//*PDS      DD DISP=(NEW,PASS),UNIT=SYSALLDA,LIKE=&$COPY,
//*            SPACE=(,(,,5)),DSNTYPE=PDS,LRECL=0   * LRECL=0 mandatory
//*
//* convert unloaded file to FB80 & save in &$PART
//*
//GIMDTS   EXEC PGM=&GIMDTS,REGION=0M,COND=(4,LT)
//*STEPLIB  DD DISP=SHR,DSN=SYS1.MIGLIB
//SYSPRINT DD DISP=MOD,DSN=&SYSOUT
//SYSUT1   DD DISP=(OLD,PASS),DSN=&$UNLOAD  * OPTIONAL OVERRIDE CALLER
//SYSUT2   DD DISP=OLD,DSN=&$PART
//*  GIMDTS:
//*    SYSUT1 data set or member to be converted
//*           RECFM must be: F, FA, FM, FB, FBA, FBM, V, VA, VM,
//*           VB, VBA OR VBM (no spanned records allowed)
//*    SYSUT2 data set or member that will contain the transformed
//*           data, RECFM = FB, LRECL = 80, BLKSIZE = (multiple of 80)
//*    SYSPRINT must be RECFM = FBA, LRECL = 121
//*
//* process final disposition of work files
//*
//DISP     EXEC PGM=IEFBR14,COND=(4,LT)
//* process final disposition of work files
//UNLOAD   DD DISP=(SHR,&DSP),DSN=&$UNLOAD
//* added by PTF@LMOD
//*PDSE     DD DISP=(SHR,&DSP),DSN=&$COPY
//*
//         ENDIF (RC <= 4)
//*
//         PEND
//*--------
//*
