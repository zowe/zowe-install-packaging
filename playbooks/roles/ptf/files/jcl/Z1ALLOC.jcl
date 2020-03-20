//Z1ALLOC  JOB
//* This program and the accompanying materials are made available under 
//* the terms of the Eclipse Public License v2.0 which accompanies this 
//* distribution, and is available at
//*  https://www.eclipse.org/legal/epl-v20.html
//*
//*  SPDX-License-Identifier: EPL-2.0
//*
//*  Copyright IBM Corporation 2020, 2020
//* --------------------------------------------------------------------
//* Change #hlq to the high level qualifier used to upload the ++SYSMOD.
//* (optional) Uncomment and change #volser to specify a volume.
//*
//         SET HLQ=#hlq
//         SET FMID=#fmid
//         SET SYSMOD1=#sysmod1
//         SET SYSMOD2=#sysmod2
//*
//ALLOC    EXEC PGM=IEFBR14
//TMP0001  DD DSN=&HLQ..ZOWE.&FMID..&SYSMOD1,
//            DISP=(NEW,CATLG,DELETE),
//            DSORG=PS,
//            RECFM=FB,
//            LRECL=80,
//            UNIT=SYSALLDA,
//            VOL=SER=#volser,
//*            BLKSIZE=6160,
//            SPACE=(TRK,(5423,15))
//TMP0002  DD DSN=&HLQ..ZOWE.&FMID..&SYSMOD2,
//            DISP=(NEW,CATLG,DELETE),
//            DSORG=PS,
//            RECFM=FB,
//            LRECL=80,
//            UNIT=SYSALLDA,
//            VOL=SER=#volser,
//*            BLKSIZE=6160,
//            SPACE=(TRK,(3270,15))
//*