//Z4APPLY  JOB
//* This program and the accompanying materials are made available under 
//* the terms of the Eclipse Public License v2.0 which accompanies this 
//* distribution, and is available at
//*  https://www.eclipse.org/legal/epl-v20.html
//*
//*  SPDX-License-Identifier: EPL-2.0
//*
//*  Copyright IBM Corporation 2020, 2020
//* --------------------------------------------------------------------
//*
//         SET CSI=#globalcsi
//*
//APPLY    EXEC PGM=GIMSMP,REGION=0M
//SMPCSI   DD DISP=OLD,DSN=&CSI 
//SMPCNTL  DD *
   SET BOUNDARY(#tzone) .
   APPLY SELECT(
     #sysmod1
     #sysmod2
   )
   CHECK 
   BYPASS(HOLDSYS,HOLDERROR) 
   REDO COMPRESS(ALL) .
//*