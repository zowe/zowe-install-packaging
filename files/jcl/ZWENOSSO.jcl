//ZWENOSSO JOB
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
//* This JCL can be used to remove SSO security profiles for Zowe
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
//* 4) Update the SET JWTLABEL= statement if you are not using the
//*    default JWT secret label.
//*
//* 5) Update the SET SSOTOKEN= variable to be the token name you
//*    would like to create.
//*
//* 6) Customize the commands in the DD statement that matches your
//*    security product so that they meet your system requirements.
//*
//* Note(s):
//*
//* 1. THE USER ID THAT RUNS THIS JOB MUST HAVE SUFFICIENT AUTHORITY
//*    TO ALTER SECURITY DEFINITIONS
//*
//* 2. ACF2 support is pending.
//*
//*********************************************************************
//         EXPORT SYMLIST=*
//*
//         SET  PRODUCT=RACF         * RACF, ACF2, or TSS
//*                     12345678
//         SET ZOWEUSER=ZWESVUSR     * userid for Zowe started task
//*                     12345678
//*
//*      * Certificate label of Zowe's JWT secret to enable SSO
//         SET  JWTLABEL='jwtsecret'
//*      * SSO token name
//         SET  SSOTOKEN=
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

/* Delete CRYPTOZ SO.<token> and USER.<token> profiles ............. */
    RDELETE CRYPTOZ (SO.&SSOTOKEN.)
    RDELETE CRYPTOZ (USER.&SSOTOKEN.)

/* Refresh and Verify                                                */
    SETROPTS RACLIST(CRYPTOZ) REFRESH
    RLIST CRYPTOZ * AUTHUSER

/* Delete Token .................................................... */
    RACDCERT DELTOKEN(&SSOTOKEN.) FORCE

/* Delete JWT secret certificate                                     */
    RACDCERT ID(&ZOWEUSER.) DELETE(LABEL('&JWTLABEL.')

/* List Zowe token certificates                                      */
    RACDCERT LISTTOKEN(&SSOTOKEN.)

/* ................................................................. */
/* only the last RC is returned, this command ensures it is a 0      */
PROFILE
$$
//*
//*********************************************************************
//*
//* Top Secret ONLY, customize to meet your system requirements
//*
//TSS      DD DATA,DLM=$$,SYMBOLS=JCLONLY

/* Delete CRYPTOZ SO.<token> and USER.<token> profiles ............. */
    TSS REVOKE(&ZOWEUSER.) CRYPTOZ(SO.&SSOTOKEN.)
    TSS REVOKE(&ZOWEUSER.) CRYPTOZ(USER.&SSOTOKEN.)

/* Refresh and Verify                                                */
    TSS WHOHAS CRYPTOZ(SO.&SSOTOKEN.)
    TSS WHOHAS CRYPTOZ(USER.&SSOTOKEN.)

/* Delete token .................................................... */
    TSS P11TOKEN TOKENDEL LABLCTKN(&SSOTOKEN.) FORCE

/* Delete JWT secret certificate                                     */
    TSS REM(&ZOWEUSER.) DIGICERT(&JWTLABEL.)

/* List Zowe token certificates                                      */
    TSS P11TOKEN TOKENLST LABLCTKN(&SSOTOKEN.)

/* ................................................................. */
/* only the last RC is returned, this command ensures it is a 0      */
PROFILE
$$
//*

