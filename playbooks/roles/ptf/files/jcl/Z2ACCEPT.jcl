//Z2ACCEPT JOB
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
//* Change #globalcsi to the data set name of your global CSI.
//* Change #dzone to your CSI distribution zone name.
//*
//ACCEPT   EXEC PGM=GIMSMP,REGION=0M
//SMPCSI   DD DISP=OLD,DSN=#globalcsi
//SMPCNTL  DD *
   SET BOUNDARY(#dzone) .
   ACCEPT SELECT(
      #fmid
   ) REDO COMPRESS(ALL) BYPASS(HOLDSYS,HOLDERROR).
//*
