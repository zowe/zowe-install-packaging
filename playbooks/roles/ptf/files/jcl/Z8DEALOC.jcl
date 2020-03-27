//Z8DEALOC JOB
//* This program and the accompanying materials are made available     
//* under the terms of the Eclipse Public License v2.0 which           
//* accompanies this distribution, and is available at                 
//* https://www.eclipse.org/legal/epl-v20.html                         
//*                                                                    
//* SPDX-License-Identifier: EPL-2.0                                   
//* 
//* Copyright IBM Corporation 2020, 2020
//* -------------------------------------------------------------------
//* De-allocate the SYSMOD datasets
//* Change #hlq to the HLQ used to upload the ++USERMOD.
//* (optional) Uncomment and change #volser to specify a volume.
//*
//         SET HLQ=#hlq
//         SET FMID=#fmid
//         SET SYSMOD1=#sysmod1
//         SET SYSMOD2=#sysmod2
//*
//DEALLOC  EXEC PGM=IEFBR14
//TMP0001  DD DSN=&HLQ..ZOWE.&FMID..&SYSMOD1,
//*            VOL=SER=#volser,
//            DISP=(OLD,DELETE,KEEP)
//TMP0002  DD DSN=&HLQ..ZOWE.&FMID..&SYSMOD2,
//*            VOL=SER=#volser,
//            DISP=(OLD,DELETE,KEEP)
//*