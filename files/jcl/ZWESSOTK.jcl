//ZWESSOTK JOB
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
//* This JCL can be used to define SSO security profiles for Zowe
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
//* 4) Update the SET JWTDSNAM= statement if you plan to import the
//*    JWT secret certificate from a data set in PKCS12 format.
//*
//* 5) Update the SET JWTLABEL= statement if you are not using the
//*    default JWT secret label.
//*
//* 6) Update the SET SSOTOKEN= variable to be the token name you
//*    would like to create.
//*
//* 7) Customize the commands in the DD statement that matches your
//*    security product so that they meet your system requirements.
//*
//* Note(s):
//*
//* 1. THE USER ID THAT RUNS THIS JOB MUST HAVE SUFFICIENT AUTHORITY
//*    TO ALTER SECURITY DEFINITIONS
//*
//* 2. If the JWT secret certificate is imported from a data set then
//*    the certificate has to be in PKCS12 format.
//*
//* 3. Customize SYS1.SAMPLIB(CSFTKDS) sample JCL to create ICSF token
//*    data set. (This step is required.)
//*
//* 4. This job WILL complete with return code 0.
//*    The results of each command must be verified after completion.
//*
//* 5. ACF2 support is pending.
//*
//*********************************************************************
//         EXPORT SYMLIST=*
//*
//         SET  PRODUCT=RACF         * RACF, ACF2, or TSS
//*                     12345678
//         SET ZOWEUSER=ZWESVUSR     * userid for Zowe started task
//*                     12345678
//*
//*      * Name of the data set containing SSO JWT secret
//         SET JWTDSNAM=
//*      * Certificate label of Zowe's JWT secret to enable SSO
//         SET JWTLABEL='jwtsecret'
//*      * SSO token name
//         SET SSOTOKEN=
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

/* Prepare permission for token usage .............................. */

/* Enable CRYPTOZ class                                              */
    SETROPTS RACLIST(CRYPTOZ)
    SETROPTS CLASSACT(CRYPTOZ)

/* Define a CRYPTOZ SO.<token> profile                               */
    RDEFINE CRYPTOZ SO.&SSOTOKEN.
    PERMIT SO.&SSOTOKEN. ACCESS(CONTROL) CLASS(CRYPTOZ) +
        ID(&ZOWEUSER.)

/* Define a CRYPTOZ USER.<token> profile                             */
    RDEFINE CRYPTOZ USER.&SSOTOKEN.
    PERMIT USER.&SSOTOKEN. ACCESS(UPDATE) CLASS(CRYPTOZ) +
        ID(&ZOWEUSER.)

/* Refresh and Verify                                                */
    SETROPTS RACLIST(CRYPTOZ) REFRESH
    RLIST CRYPTOZ SO.&SSOTOKEN. AUTHUSER
    RLIST CRYPTOZ USER.&SSOTOKEN. AUTHUSER

/* ***************************************************************** */
/* ATTENTION!                                                        */
/* Import SSO JWT secret certificate for Zowe .......................*/
/*                                                                   */
/* If you want to import JWT secret certificate from data set into   */
/*     RACF, you can un comment out section "Import JWT secret"      */
/*     below.                                                        */
/* ***************************************************************** */
/*                                                                   */
/* Import JWT secret - BEGINNING ................................... */

/* Import certificate                                                */
/*  RACDCERT ADD('&JWTDSNAM.') +
/*           ID(&ZOWEUSER.) +
/*           WITHLABEL('&JWTLABEL.') +
/*           TRUST
/*  SETROPTS RACLIST(DIGTCERT, DIGTRING) REFRESH

/* List imported certificate                                         */
/*  RACDCERT LIST ID(&ZOWEUSER.)

/* Import JWT secret - END ......................................... */

/* Create token .................................................... */
    RACDCERT ADDTOKEN(&SSOTOKEN.)

/* Bind JWT secret to profile ...................................... */
    RACDCERT BIND(TOKEN(&SSOTOKEN.) +
             ID(&ZOWEUSER.) +
             LABEL('&JWTLABEL.'))
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

/* Prepare permission for token usage .............................. */

/* Define a CRYPTOZ SO.<token> profile                               */
    TSS ADD(&ZOWEUSER.) CRYPTOZ(SO.&SSOTOKEN.)
    TSS PERMIT(&ZOWEUSER.) CRYPTOZ(SO.&SSOTOKEN.) ACCESS(UPDATE)

/* Define a CRYPTOZ USER.<token> profile                             */
    TSS ADD(&ZOWEUSER.) CRYPTOZ(USER.&SSOTOKEN.)
    TSS PERMIT(&ZOWEUSER.) CRYPTOZ(USER.&SSOTOKEN.) ACCESS(UPDATE)

/* Refresh and Verify                                                */
    TSS WHOHAS CRYPTOZ(SO.&SSOTOKEN.)
    TSS WHOHAS CRYPTOZ(USER.&SSOTOKEN.)

/* ***************************************************************** */
/* ATTENTION!                                                        */
/* Import SSO JWT secret certificate for Zowe .......................*/
/*                                                                   */
/* If you want to import JWT secret certificate from data set into   */
/*     RACF, you can un comment out section "Import JWT secret"      */
/*     below.                                                        */
/* ***************************************************************** */
/*                                                                   */
/* Import JWT secret - BEGINNING ................................... */

/* Import certificate                                                */
/*  TSS CHKCERT DCDSN('&JWTDSNAM.')
/*  TSS ADD(&ZOWEUSER.) +
/*      DIGICERT(&JWTLABEL.) +
/*      LABLCERT('&JWTLABEL.') +
/*      DCDSN('&JWTDSNAM.') TRUST

/* List imported certificate                                         */
/*  TSS LIST(&ZOWEUSER.) DIGICERT(ALL)

/* Import JWT secret - END ......................................... */

/* Create token .................................................... */
    TSS P11TOKEN TOKENADD LABLCTKN(&SSOTOKEN.)

/* Bind JWT secret to profile ...................................... */
    TSS P11TOKEN BIND LABLCTKN(&SSOTOKEN.) +
             TOKNUSER(&ZOWEUSER.) +
             LABLCERT('&JWTLABEL.')
/* List Zowe token certificates                                      */
    TSS P11TOKEN TOKENLST LABLCTKN(&SSOTOKEN.)

/* ................................................................. */
/* only the last RC is returned, this command ensures it is a 0      */
PROFILE
$$
//*

