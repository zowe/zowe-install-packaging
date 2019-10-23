//*
//* PROC to stage file for SYSMOD creation, front-end for LMOD
//*
//*--------
//PTF@LMOD PROC HLQ=&HLQ,               * work HLQ
//*           MCS=&MCS,                 * MCS path, must be inherited
//            REL=&REL,                 * hlq.F1, hlq.F2, ...
//            MVS=                      * member name Fx(<member>)
//*
//         SET $COPY=&HLQ..$C.&MVS
//*
//PTF@LMOD EXEC PROC=PTF@,
//*            DSP='CATLG',              * final DISP of temp files
//*            SIZE='CYL,(1,50)',        * temp file size
//* enable a step
//            UNLOAD=IKJEFT01,          * IEFBR14 (skip) or IKJEFT01
//            GIMDTS=GIMDTS             * IEFBR14 (skip) or GIMDTS
//* input
//UNLOAD.SYSUT1 DD DISP=SHR,DSN=&REL(&MVS)
//* work files
//UNLOAD.PDSE DD DISP=(NEW,PASS),SPACE=(&SIZE,RLSE),UNIT=SYSALLDA,
#volser
//            LIKE=&REL,DSNTYPE=LIBRARY,LRECL=0,DSN=&$COPY
//UNLOAD.PDS DD DISP=(NEW,PASS),UNIT=SYSALLDA,LIKE=&$COPY,
#volser
//            SPACE=(,(,,5)),DSNTYPE=PDS,LRECL=0   * LRECL=0 mandatory
//* set final disposition
//DISP.PDSE DD DISP=(SHR,&DSP),DSN=&$COPY
//*
//         PEND
//*--------
//*
