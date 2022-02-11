//ZWENOKYR JOB
//*
//* This program and the accompanying materials are made available
//* under the terms of the Eclipse Public License v2.0 which
//* accompanies this distribution, and is available at
//* https://www.eclipse.org/legal/epl-v20.html
//*
//* SPDX-License-Identifier: EPL-2.0
//*
//* Copyright Contributors to the Zowe Project. 2020, 2020
//*
//*********************************************************************
//*
//* Zowe Open Source Project
//* This JCL can be used to define key ring and certificates for Zowe
//*
//*
//* CAUTION: This is neither a JCL procedure nor a complete job.
//* Before using this JCL, you will have to make the following
//* modifications:
//*
//* 1) Add job name and job parameters to the JOB statement, to
//*    meet your system requirements.
//*
//* 2) Update the SET PRODUCT= statement to match your security
//*    product.
//*
//* 3) Update the SET ZOWEUSER= statement to match the existing
//*    user ID for the Zowe started task.
//*
//* 4) Update the SET ZOWERING= statement to match the desired
//*    name of the keyring owned by the &ZOWEUSER user ID.
//*
//* 5) Update the SET LABEL= statement with the name of the Zowe
//*    certificate that will be added to the security database or
//*    that is already stored in the security database.
//*
//* 6) Specify the Zowe's local CA by updating the SET LOCALCA=
//*
//* 7) Customize the commands in the DD statement that matches your
//*    security product so that they meet your system requirements.
//*
//* Note(s):
//*
//* 1. THE USER ID THAT RUNS THIS JOB MUST HAVE SUFFICIENT AUTHORITY
//*    TO ALTER SECURITY DEFINITIONS
//*
//* 2. This job WILL complete with return code 0.
//*    The results of each command must be verified after completion.
//*
//*********************************************************************
//         EXPORT SYMLIST=*
//*
//         SET  PRODUCT=RACF         * RACF, ACF2, or TSS
//*                     12345678
//         SET ZOWEUSER=ZWESVUSR     * userid for Zowe started task
//*                     12345678
//*
//*      * Keyring for the Zowe userid
//         SET ZOWERING='ZoweKeyring'
//*      * Zowe's certificate label
//         SET    LABEL='localhost'
//*      * Zowe's local CA name
//         SET  LOCALCA='localca'
//*
//* ACF2 ONLY -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
//*                     12345678
//         SET   STCGRP=          * group for Zowe started tasks
//*                     12345678
//*
//* end ACF2 ONLY -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
//*
//*********************************************************************
//*
//* EXECUTE COMMANDS FOR SELECTED SECURITY PRODUCT
//*
//RUN      EXEC PGM=IKJEFT01,REGION=0M
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DDNAME=&PRODUCT
//*
//*********************************************************************
//*
//* RACF ONLY, customize to meet your system requirements
//*
//RACF     DD DATA,DLM=$$,SYMBOLS=JCLONLY

/* Remove permit to use SITE owned certificate's private key */
  PERMIT IRR.DIGTCERT.GENCERT CLASS(FACILITY) DELETE ID(&ZOWEUSER.)

/* Remove permit to read keyring ................................... */
  PERMIT IRR.DIGTCERT.LISTRING CLASS(FACILITY) DELETE ID(&ZOWEUSER.)

  SETROPTS RACLIST(FACILITY) REFRESH

/* Delete LABEL certificate ........................................*/
  RACDCERT DELETE(LABEL('&LABEL.')) ID(&ZOWEUSER.)

/* Delete LOCALCA certificate ......................................*/
  RACDCERT DELETE(LABEL('&LOCALCA.')) CERTAUTH

/* Delete keyring ...................................................*/
  RACDCERT DELRING(&ZOWERING.) ID(&ZOWEUSER.)

  SETROPTS RACLIST(DIGTCERT, DIGTRING) REFRESH

/* ................................................................. */
/* only the last RC is returned, this command ensures it is a 0      */
PROFILE
$$
//*
//*********************************************************************
//*
//* ACF2 ONLY, customize to meet your system requirements
//*
//ACF2     DD DATA,DLM=$$,SYMBOLS=JCLONLY
ACF

* Remove permit to use SITE owned certificate's private key
  SET RESOURCE(FAC)
  RECKEY IRR DEL(DIGTCERT.GENCERT ROLE(&STCGRP) +
  SERVICE(CONTROL) ALLOW)

* Remove permit to read keyring ....................................*/
  RECKEY IRR DEL(DIGTCERT.LISTRING ROLE(&STCGRP) +
  SERVICE(READ) ALLOW)

  F ACF2,REBUILD(FAC)

* Delete LABEL certificate ........................................*/
  DELETE &ZOWEUSER..ZOWECERT

* Delete LOCALCA certificate ......................................*/
  DELETE CERTAUTH.ZOWECA

* Delete keyring ...................................................*/
  SET PROFILE(USER) DIVISION(KEYRING)
  DELETE &ZOWEUSER..ZOWERING

  F ACF2,REBUILD(USR),CLASS(P),DIVISION(KEYRING)

END
$$
//*
//*********************************************************************
//*
//* Top Secret ONLY, customize to meet your system requirements
//*
//TSS      DD DATA,DLM=$$,SYMBOLS=JCLONLY

/* Remove permit to use SITE owned certificate's private key */
   TSS REVOKE(&ZOWEUSER.) IBMFAC(IRR.DIGTCERT.GENCERT) ACCESS(CONTROL)

/* Remove permit to read keyring ................................... */
   TSS REVOKE(&ZOWEUSER.) IBMFAC(IRR.DIGTCERT.LISTRING) ACCESS(READ)

/* Delete LABEL certificate ........................................*/
   TSS REM(&ZOWEUSER.) DIGICERT(ZOWECERT)

/* Delete LOCALCA certificate ......................................*/
   TSS REM(CERTAUTH) DIGICERT(ZOWECA)

/* Delete keyring ...................................................*/
   TSS REM(&ZOWEUSER.) KEYRING(ZOWERING)

/* ................................................................. */
/* only the last RC is returned, this command ensures it is a 0      */
PROFILE
$$
//*

