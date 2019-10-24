//*
//* PROC to stage file for SYSMOD creation, front-end for FB80
//*
//*--------
//PTF@FB80 PROC HLQ=&HLQ,                 * work HLQ
//            REL=&REL,                   * hlq.F1, hlq.F2, ...
//            MBR=                        * member name Fx(<member>)
//*
//PTF@FB80 EXEC PROC=PTF@,
//*            DSP='CATLG',                * final DISP of temp files
//*            SIZE='TRK,(#trks)',        * temp file size
//* enable a step
//            UNLOAD=IKJEFT01             * IEFBR14 (skip) or IKJEFT01
//* input
//UNLOAD.SYSUT1 DD DISP=SHR,DSN=&REL(&MBR)                 MBR optional
//* result
//UNLOAD.SYSUT2 DD DDNAME=PART
//*
//         PEND
//*--------
//*
