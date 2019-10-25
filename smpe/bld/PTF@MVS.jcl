//*
//* PROC to stage file for SYSMOD creation, front-end for NON-LMOD
//*
//*--------
//PTF@MVS  PROC HLQ=&HLQ,                 * work HLQ
//            REL=&REL,                   * hlq.F1, hlq.F2, ...
//            MBR=                        * member name Fx(<member>)
//*
//PTF@MVS  EXEC PROC=PTF@,
//*            DSP='CATLG',                * final DISP of temp files
//*            SIZE='TRK,(#trks)',        * temp file size
//* enable a step
//            GIMDTS=GIMDTS               * IEFBR14 (skip) or GIMDTS
//* input
//GIMDTS.SYSUT1 DD DISP=SHR,DSN=&REL(&MBR)                 MBR required
//*
//         PEND
//*--------
//*
