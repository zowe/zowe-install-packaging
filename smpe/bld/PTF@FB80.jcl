//*
//* PROC to stage file for SYSMOD creation, front-end for FB80
//*
//*--------
//PTF@FB80 PROC HLQ=&HLQ,               * work HLQ
//*           MCS=&MCS,                 * MCS path, must be inherited
//            REL=&REL,                 * hlq.F1, hlq.F2, ...
//            MVS=                      * member name Fx(<member>)
//*
//PTF@FB80 EXEC PROC=PTF@,
//*            DSP='CATLG',              * final DISP of temp files
//*            SIZE='CYL,(1,50)',        * temp file size
//* enable a step
//            UNLOAD=IKJEFT01           * IEFBR14 (skip) or IKJEFT01
//* input
//UNLOAD.SYSUT1 DD DISP=SHR,DSN=&REL(&MVS)
//* output
//UNLOAD.SYSUT2 DD DDNAME=PART
//*
//         PEND
//*--------
//*
