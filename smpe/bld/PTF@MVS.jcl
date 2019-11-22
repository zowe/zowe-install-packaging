//*--------------------------------------------------------------------
//* This program and the accompanying materials are made available
//* under the terms of the Eclipse Public License v2.0 which
//* accompanies this distribution, and is available at
//* https://www.eclipse.org/legal/epl-v20.html
//*
//* SPDX-License-Identifier: EPL-2.0
//*
//* Copyright Contributors to the Zowe Project. 2019, 2019
//*--------------------------------------------------------------------
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
