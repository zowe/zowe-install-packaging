//Z3RECEIV JOB
//* This program and the accompanying materials are made available     
//* under the terms of the Eclipse Public License v2.0 which           
//* accompanies this distribution, and is available at                 
//* https://www.eclipse.org/legal/epl-v20.html                         
//*                                                                    
//* SPDX-License-Identifier: EPL-2.0                                   
//* 
//* Copyright IBM Corporation 2020
//* -------------------------------------------------------------------
//*
//* Change #hlq to the HLW used to upload the ++USERMOD.
//* Change #globalcsi to the data set name of your global CSI.
//*
//         SET HLQ=#hlq
//         SET CSI=#globalcsi
//         SET FMID=#fmid 
//         SET SYSMOD1=#sysmod1
//         SET SYSMOD2=#sysmod2
//*
//RECEIVE  EXEC PGM=GIMSMP,REGION=0M
//SMPCSI   DD DISP=OLD,DSN=&CSI
//SMPPTFIN DD DISP=SHR,DSN=&HLQ..ZOWE.&FMID..&SYSMOD1
//         DD DISP=SHR,DSN=&HLQ..ZOWE.&FMID..&SYSMOD2
//SMPCNTL  DD *
   SET BOUNDARY(GLOBAL) .
   RECEIVE SELECT(
     #sysmod1
     #sysmod2
   ) SYSMODS LIST .
//*

