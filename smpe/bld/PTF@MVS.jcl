//*
//* PROC to stage file for SYSMOD creation, front-end for NON-LMOD
//*
//*--------
//PTF@MVS  PROC HLQ=&HLQ,               * work HLQ
//*           MCS=&MCS,                 * MCS path, must be inherited
//            REL=&REL,                 * hlq.F1, hlq.F2, ...
//            MVS=                      * member name Fx(<member>)
//*
//PTF@MVS  EXEC PROC=PTF@,
//*            DSP='CATLG',              * final DISP of temp files
//*            SIZE='CYL,(1,50)',        * temp file size
//* enable a step
//            GIMDTS=GIMDTS             * IEFBR14 (skip) or GIMDTS
//* input
//GIMDTS.SYSUT1 DD DISP=SHR,DSN=&REL(&MVS)
//*
//         PEND
//*--------
//*
