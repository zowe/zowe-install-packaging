//ZWEKRING JOB
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
//*********************************************************************
//* ATTENTION!
//* Configure certificate for Zowe
//* Select one of three options which is the most suitable for your
//* environment and follow the appropriate action
//*
//* Options:
//*  1. (default option) Generate Zowe's certificate that will be
//*     signed by the Zowe's local CA
//*
//*  2. Zowe's certificate is already loaded in RACF database
//*     ACTION:
//*     a. modify the following snippet
//*        CONNECT(SITE | ID(userid) +
//*        LABEL('certlabel') +
//*        to match the owner of the desired certificate
//*
//*  3. Import external Zowe's certificate from a data set in PKCS12
//*     format
//*
//*********************************************************************
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
//* 5) Specify the option number which is suitable for your
//*    environment by the SET OPTION statement.
//*    Option 1 considers as default option.
//*
//* 6) Update the SET LABEL= statement with the name of the Zowe
//*    certificate that will be defined, or added to the security
//*    database or if that is already stored in the security database.
//*
//* 7) Specify the distinguished name of the Zowe's local CA by
//*    updating the SET statements CN=, OU=, O=, L=, SP=, C=, and
//*    LOCALCA=.
//*
//* 8) Update the SET HOSTNAME= variable to match the hostname where
//*    Zowe is to run.
//*
//* 9) Update the SET IPADDRES= variable to match the IP address
//*    where Zowe is to run.
//*
//* 10) Update the SET DSNAME= statement if you plan to add the Zowe
//*     certificate from a data set in PKCS12 format.
//*
//* 11) Update the SET PKCSPASS= statement to match the password for
//*     the PKCS12 data set.
//*
//* 12) Set IFZOWECA to 1 if the Zowe certificate signed by a
//*     recognized certificate authority (CA).
//*
//* 13) Update the SET ITRMZWCA= variable to match the intermediate
//*     CA of the Zowe certificate. It is only applicable if Zowe
//*     certificate signed by a recognized certificate authority (CA).
//*
//* 14) Update the SET ROOTZWCA= variable to match the root CA of the
//*     Zowe certificate. It is only applicable if Zowe certificate
//*     signed by a recognized certificate authority (CA).
//*
//* 15) Set IFROZFCA to 1 if the z/OSMF crtificate signed by a
//*     recognized certificate authority (CA).
//*
//* 16) Update the SET ROOTZFCA= variable to match the root CA of the
//*     z/OSMF certificate. It is only applicable if z/OSMF
//*     certificate signed by a recognized certificate authority (CA).
//*
//* 17) Update the SET JWTLABEL= statement if you are not using the
//*     default JWT secret label.
//*
//* 18) Customize the commands in the DD statement that matches your
//*     security product so that they meet your system requirements.
//*
//* Note(s):
//*
//* 1. The userid that runs this job must have sufficient authority
//*    to alter security definitions
//*
//* 2. Assumption: signing CA chain of the Zowe external certificate is
//*    added to the security database under the CERTAUTH userid.
//*
//* 3. If the Zowe certificate is imported from a data set then
//*    the certificate has to be in PKCS12 format and has to
//*    contain Zowe certificate's signing CA chain and private key.
//*
//* 4. This job WILL complete with return code 0.
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
//*      * Option number to configure Zowe certificate
//*      * Valid options: 1,2,3
//*      * Default option is 1
//         SET OPTION=1
//*      * Zowe's certificate label
//         SET LABEL='localhost'
//*      * Zowe's local CA name
//         SET LOCALCA='localca'
//*      * Zowe's local CA common name
//         SET CN='Zowe Development Instances'
//*      * Zowe's local CA organizational unit
//         SET OU='API Mediation Layer'
//*      * Zowe's local CA organization
//         SET O='Zowe Sample'
//*      * Zowe's local CA city/locality
//         SET L='Prague'
//*      * Zowe's local CA state/province
//         SET SP='Prague'
//*      * Zowe's local CA country
//         SET C='CZ'
//*      * Hostname of the system where Zowe is to run
//         SET HOSTNAME=''
//*      * IP address of the system where Zowe is to run
//         SET IPADDRES=''
//*      * Name of the data set containing Zowe's certificate (PKCS12)
//         SET DSNAME=
//*      * Password for the PKCS12 data set
//         SET PKCSPASS=''
//*      * IF the Zowe certificate signed by a recognized certificate
//*      * authority (CA),set IFZOWECA to 1
//         SET IFZOWECA=0
//*      * Label of the intermediate CA of the Zowe certificate
//*        if applicable
//         SET ITRMZWCA=''
//*      * Label of the root CA of the Zowe certificate if applicable
//         SET ROOTZWCA=''
//*      * IF the z/OSMF certificate signed by a recognized
//*      * certificate authority (CA),set IFROZFCA to 1
//         SET IFROZFCA=0
//*      * Label of the root CA of the z/OSMF certificate if
//*        applicable
//         SET ROOTZFCA=''
//*      * Certificate label of Zowe's JWT secret
//         SET JWTLABEL='jwtsecret'
//*
//* ACF2 ONLY -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
//*                     12345678
//         SET STCGRP=          * group for Zowe started tasks
//*                     12345678
//*
//* end ACF2 ONLY -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
//*
//*********************************************************************
//*
//* EXECUTE COMMANDS FOR SELECTED SECURITY PRODUCT
//*
//RUNRACF  EXEC PGM=IKJEFT01,REGION=0M
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DDNAME=&PRODUCT
//*
//*********************************************************************
//*
//* RACF ONLY, customize to meet your system requirements
//*
//RACF     DD DATA,DLM=$$,SYMBOLS=JCLONLY

/* Create the keyring .............................................. */
   RACDCERT ADDRING(&ZOWERING.) ID(&ZOWEUSER.)
   SETROPTS RACLIST(DIGTRING) REFRESH
$$
//IFOPT1   IF (&OPTION EQ 1) THEN
//RUNOPT1  EXEC PGM=IKJEFT01,REGION=0M
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DDNAME=&PRODUCT
//RACF     DD DATA,DLM=$$,SYMBOLS=JCLONLY

/* Option 1 - Default Option - BEGINNING ........................... */
/* Create Zowe's local CA authority .................................*/
   RACDCERT GENCERT CERTAUTH +
            SUBJECTSDN( +
              CN('&CN. CA') +
              OU('&OU.') +
              O('&O.') +
              L('&L.') +
              SP('&SP.') +
              C('&C.')) +
            SIZE(2048) +
            NOTAFTER(DATE(2030-05-01)) +
            WITHLABEL('&LOCALCA') +
            KEYUSAGE(CERTSIGN)

/* Connect Zowe's local CA authority to the keyring ................ */
   RACDCERT CONNECT(CERTAUTH LABEL('&LOCALCA') +
            RING(&ZOWERING.)) +
            ID(&ZOWEUSER.)

/* Create a certificate signed by local zowe's CA .................. */
   RACDCERT GENCERT ID(&ZOWEUSER.) +
            SUBJECTSDN( +
              CN('&CN. certificate') +
              OU('&OU.') +
              O('&O.') +
              L('&L.') +
              SP('&SP.') +
              C('&C.')) +
            SIZE(2048) +
            NOTAFTER(DATE(2030-05-01)) +
            WITHLABEL('&LABEL.') +
            KEYUSAGE(HANDSHAKE) +
            ALTNAME(IP(&IPADDRES) +
                DOMAIN('&HOSTNAME')) +
            SIGNWITH(CERTAUTH LABEL('&LOCALCA'))

/* Connect a Zowe's certificate with the keyring ................... */
   RACDCERT CONNECT(ID(&ZOWEUSER.) +
            LABEL('&LABEL.') +
            RING(&ZOWERING.) +
            USAGE(PERSONAL) DEFAULT) +
            ID(&ZOWEUSER.)

   SETROPTS RACLIST(DIGTCERT,DIGTRING) REFRESH

/* Option 1 - Default Option - END ................................. */
$$
//IFOPT1ED ENDIF
//*
//IFOPT2   IF (&OPTION EQ 2) THEN
//RUNOPT2  EXEC PGM=IKJEFT01,REGION=0M
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DDNAME=&PRODUCT
//RACF     DD DATA,DLM=$$,SYMBOLS=JCLONLY

/* Option 2 - BEGINNING ............................................ */
/* Connect a Zowe's certificate with the keyring ................... */
   RACDCERT CONNECT(SITE | ID(userid) +
            LABEL('certlabel') +
            RING(&ZOWERING.) +
            USAGE(PERSONAL) DEFAULT) +
            ID(&ZOWEUSER.)

   SETROPTS RACLIST(DIGTCERT,DIGTRING) REFRESH

/* Option 2 - END .................................................. */
$$
//IFOPT2ED ENDIF
//*
//IFOPT3   IF (&OPTION EQ 3) THEN
//RUNOPT3  EXEC PGM=IKJEFT01,REGION=0M
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DDNAME=&PRODUCT
//RACF     DD DATA,DLM=$$,SYMBOLS=JCLONLY

/* Option 3 - BEGINNING ............................................ */
/* Import external certificate from data set ....................... */
   RACDCERT ADD('&DSNAME.') +
            ID(&ZOWEUSER.) +
            WITHLABEL('&LABEL.') +
            PASSWORD('&PKCSPASS.') +
            TRUST

/* Connect a Zowe's certificate with the keyring ................... */
   RACDCERT CONNECT(ID(&ZOWEUSER.) +
            LABEL('&LABEL.') +
            RING(&ZOWERING.) +
            USAGE(PERSONAL) DEFAULT) +
            ID(&ZOWEUSER.)

   SETROPTS RACLIST(DIGTCERT,DIGTRING) REFRESH

/* Option 3 - END .................................................. */
$$
//IFOPT3ED ENDIF
//*
//IFZWCA   IF (&IFZOWECA EQ 1) THEN
//RUNZWCA  EXEC PGM=IKJEFT01,REGION=0M
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DDNAME=&PRODUCT
//RACF     DD DATA,DLM=$$,SYMBOLS=JCLONLY

/* Connect all CAs of the Zowe certificate's signing chain with the  */
/* keyring ......................................................... */
   RACDCERT CONNECT(CERTAUTH +
            LABEL('&ITRMZWCA.') +
            RING(&ZOWERING.) USAGE(CERTAUTH)) +
            ID(&ZOWEUSER.)

   RACDCERT CONNECT(CERTAUTH +
            LABEL('&ROOTZWCA.') +
            RING(&ZOWERING.) USAGE(CERTAUTH)) +
            ID(&ZOWEUSER.)

   SETROPTS RACLIST(DIGTCERT,DIGTRING) REFRESH
$$
//IFZWCAED ENDIF
//*
//IFZFCA   IF (&IFROZFCA EQ 1) THEN
//RUNZFCA  EXEC PGM=IKJEFT01,REGION=0M
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DDNAME=&PRODUCT
//RACF     DD DATA,DLM=$$,SYMBOLS=JCLONLY

/* Connect the z/OSMF root CA signed by a recognized certificate ... */
/* authority (CA) with the keyring ................................. */
   RACDCERT CONNECT(CERTAUTH +
            LABEL('&ROOTZFCA.') +
            RING(&ZOWERING.) USAGE(CERTAUTH)) +
            ID(&ZOWEUSER.)

   SETROPTS RACLIST(DIGTCERT,DIGTRING) REFRESH
$$
//IFZFCAED ENDIF
//*
//COMRACF  EXEC PGM=IKJEFT01,REGION=0M
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DDNAME=&PRODUCT
//RACF     DD DATA,DLM=$$,SYMBOLS=JCLONLY

/* A common part for all options - BEGINNING ....................... */
/* Create jwt secret ............................................... */
   RACDCERT GENCERT ID(&ZOWEUSER.) +
            SUBJECTSDN( +
              CN('&CN. JWT') +
              OU('&OU.') +
              O('&O.') +
              L('&L.') +
              SP('&SP.') +
              C('&C.')) +
            SIZE(2048) +
            NOTAFTER(DATE(2030-05-01)) +
            WITHLABEL('&JWTLABEL.')

/* Connect jwt secret to the keyring ............................... */
   RACDCERT CONNECT(ID(&ZOWEUSER.) LABEL('&JWTLABEL.') +
            RING(&ZOWERING.) USAGE(PERSONAL)) +
            ID(&ZOWEUSER.)

   SETROPTS RACLIST(DIGTCERT,DIGTRING) REFRESH

/* Allow ZOWEUSER to access keyring ................................ */
   PERMIT IRR.DIGTCERT.LISTRING CLASS(FACILITY) ID(&ZOWEUSER.) +
          ACCESS(READ)

   SETROPTS RACLIST(FACILITY) REFRESH

/* List the keyring ................................................ */
   RACDCERT LISTRING(&ZOWERING.) ID(&ZOWEUSER.)

/* Common part - END ................................................ */
/* only the last RC is returned, this command ensures it is a 0 .... */
PROFILE
$$
//*******************************************************************
//*
//* ACF2 ONLY, customize to meet your system requirements
//*
//*******************************************************************
//RUNACF2  EXEC PGM=IKJEFT01,REGION=0M
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DDNAME=&PRODUCT
//*
//ACF2     DD DATA,DLM=$$,SYMBOLS=JCLONLY
ACF
//
* Create the keyring .............................................. */
  SET PROFILE(USER) DIVISION(KEYRING)
  INSERT &ZOWEUSER..ZOWERING RINGNAME(&ZOWERING.)
  F ACF2,REBUILD(USR),CLASS(P),DIVISION(KEYRING)
$$
//IFOPT1   IF (&OPTION EQ 1) THEN
//RUNOPT1  EXEC PGM=IKJEFT01,REGION=0M
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DDNAME=&PRODUCT
//ACF2     DD DATA,DLM=$$,SYMBOLS=JCLONLY
ACF
//
* Option 1 - Default Option - BEGINNING ........................... */
* Create Zowe's local CA authority ................................ */
  SET PROFILE(USER) DIVISION(CERTDATA)
  GENCERT CERTAUTH.ZOWECA LABEL(&LOCALCA) SIZE(2048) -
          SUBJSDN(CN='&CN. CA' -
                  OU='&OU.' -
                  O='&O.' -
                  L='&L.' -
                  SP='&SP.' -
                  C='&C.') -
  EXPIRE(05/01/30) -
  KEYUSAGE(CERTSIGN)
*
* Connect Zowe's local CA authority to the keyring ................ */
  SET PROFILE(USER) DIVISION(CERTDATA)
  CONNECT CERTDATA(CERTAUTH.ZOWECA) RINGNAME(&ZOWERING.) -
  KEYRING(&ZOWEUSER..ZOWERING) USAGE(CERTAUTH)
  CHKCERT CERTAUTH.ZOWECA
*
* Create a certificate signed by local zowe's CA .................. */
   SET PROFILE(USER) DIV(CERTDATA)
   GENCERT &ZOWEUSER..ZOWECERT -
            SUBJSDN(CN='&CN. certificate' -
                    OU='&OU.' -
                    O='&O.' -
                    L='&L.' -
                    SP='&SP.' -
                    C='&C.') -
           SIZE(2048) -
           EXPIRE(05/01/30) -
           LABEL(&LABEL.) -
           KEYUSAGE(HANDSHAKE) -
           ALTNAME(IP=&IPADDRES DOMAIN=&HOSTNAME) -
           SIGNWITH(CERTAUTH.ZOWECA)
*
* Connect a Zowe's certificate with the keyring ................... */
   SET PROFILE(USER) DIVISION(CERTDATA)
   CONNECT CERTDATA(&ZOWEUSER..ZOWECERT) -
   KEYRING(&ZOWEUSER..ZOWERING) USAGE(PERSONAL) DEFAULT
   CHKCERT &ZOWEUSER..ZOWECERT
*
* Option 1 - Default Option - END ................................. */
$$
//IFOPT1ED ENDIF
//*
//IFOPT2   IF (&OPTION EQ 2) THEN
//RUNOPT2  EXEC PGM=IKJEFT01,REGION=0M
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DDNAME=&PRODUCT
//ACF2     DD DATA,DLM=$$,SYMBOLS=JCLONLY
ACF
//
* Option 2 - BEGINNING ............................................ */
* Connect a Zowe's certificate with the keyring ................... */
   SET PROFILE(USER) DIVISION(CERTDATA)
   CONNECT CERTDATA(SITECERT.digicert | userid.digicert) -
   KEYRING(&ZOWEUSER..ZOWERING) USAGE(PERSONAL) DEFAULT
   CHKCERT &ZOWEUSER..ZOWECERT
*
* Option 2 - END .................................................. */
$$
//IFOPT2ED ENDIF
//*
//IFOPT3   IF (&OPTION EQ 3) THEN
//RUNOPT3  EXEC PGM=IKJEFT01,REGION=0M
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DDNAME=&PRODUCT
//ACF2     DD DATA,DLM=$$,SYMBOLS=JCLONLY
ACF
//
* Option 3 - BEGINNING ............................................ */
* Import external certificate from data set ....................... */
   SET PROFILE(USER) DIV(CERTDATA)
   INSERT &ZOWEUSER..ZOWECERT -
          DSNAME('&DSNAME.') -
          LABEL(&LABEL.) -
          PASSWORD('&PKCSPASS.') -
          TRUST
*
* Connect a Zowe's certificate with the keyring ................... */
   SET PROFILE(USER) DIVISION(CERTDATA)
   CONNECT CERTDATA(&ZOWEUSER..ZOWECERT) -
   KEYRING(&ZOWEUSER..ZOWERING) USAGE(PERSONAL) DEFAULT
   CHKCERT &ZOWEUSER..ZOWECERT
*
* Option 3 - END .................................................. */
$$
//IFOPT3ED ENDIF
//*
//IFZWCA   IF (&IFZOWECA EQ 1) THEN
//RUNZWCA  EXEC PGM=IKJEFT01,REGION=0M
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DDNAME=&PRODUCT
//ACF2     DD DATA,DLM=$$,SYMBOLS=JCLONLY
ACF
//
* Connect all CAs of the Zowe certificate's signing chain with the  */
* keyring ......................................................... */
   SET PROFILE(USER) DIVISION(CERTDATA)
   CONNECT CERTDATA(CERTAUTH.&ITRMZWCA.) RINGNAME(&ZOWERING.) -
   KEYRING(&ZOWEUSER..ZOWERING) USAGE(CERTAUTH)
*
   CONNECT CERTDATA(CERTAUTH.&ROOTZWCA.) RINGNAME(&ZOWERING.) -
   KEYRING(&ZOWEUSER..ZOWERING) USAGE(CERTAUTH)
$$
//IFZWCAED ENDIF
//*
//IFZFCA   IF (&IFROZFCA EQ 1) THEN
//RUNZFCA  EXEC PGM=IKJEFT01,REGION=0M
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DDNAME=&PRODUCT
//ACF2     DD DATA,DLM=$$,SYMBOLS=JCLONLY
ACF
//
* Connect the z/OSMF root CA signed by a recognized certificate ... */
* authority (CA) with the keyring ................................. */
   SET PROFILE(USER) DIVISION(CERTDATA)
   CONNECT CERTDATA(CERTAUTH.&ROOTZFCA.) RINGNAME(&ZOWERING.) -
   KEYRING(&ZOWEUSER..ZOWERING) USAGE(CERTAUTH)
$$
//IFZFCAED ENDIF
//*
//COMACF2  EXEC PGM=IKJEFT01,REGION=0M
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DDNAME=&PRODUCT
//ACF2     DD DATA,DLM=$$,SYMBOLS=JCLONLY
ACF
//
* A common part for all options - BEGINNING ....................... */
* Create jwt secret ............................................... */
   SET PROFILE(USER) DIVISION(CERTDATA)
   GENCERT &ZOWEUSER..ZOWEJWT -
           SUBJSDN(CN='&CN. JWT' -
                   OU='&OU.' -
                    O='&O.' -
                    L='&L.' -
                   SP='&SP.' -
                   C='&C.') -
           SIZE(2048) -
           LABEL(&JWTLABEL.) -
           EXPIRE(05/01/30)
*
* Connect jwt secret to the keyring ............................... */
  SET PROFILE(USER) DIVISION(CERTDATA)
  CONNECT CERTDATA(&ZOWEUSER..ZOWEJWT) RINGNAME(&ZOWERING.) -
  KEYRING(&ZOWEUSER..ZOWERING) USAGE(PERSONAL)
  CHKCERT &ZOWEUSER..ZOWEJWT
*
* Allow ZOWEUSER to access keyring ................................ */
  SET RESOURCE(FAC)
  RECKEY IRR ADD(DIGTCERT.LISTRING ROLE(&STCGRP) -
  SERVICE(READ) ALLOW)
*
  F ACF2,REBUILD(FAC)
*
* List the keyring ................................................ */
  SET PROFILE(USER) DIVISION(KEYRING)
  LIST &ZOWEUSER..ZOWERING
* Common part - END ............................................... */
$$
//********************************************************************
//*
//* Top Secret ONLY, customize to meet your system requirements
//*
//********************************************************************
//RUNTSS   EXEC PGM=IKJEFT01,REGION=0M
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DDNAME=&PRODUCT
//*
//TSS      DD DATA,DLM=$$,SYMBOLS=JCLONLY

/* Create the keyring .............................................. */
  TSS ADD(&ZOWEUSER.) KEYRING(ZOWERING) LABLRING(&ZOWERING.)
$$
//IFOPT1   IF (&OPTION EQ 1) THEN
//RUNOPT1  EXEC PGM=IKJEFT01,REGION=0M
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DDNAME=&PRODUCT
//TSS      DD DATA,DLM=$$,SYMBOLS=JCLONLY

/* Create Zowe's local CA authority ............................... */
  TSS GENCERT(CERTAUTH) +
        DIGICERT(ZOWECA) +
        SUBJECTN( +
          'CN="&CN. CA" +
          OU="&OU." +
          O="&O." +
          L="&L." +
          SP="&SP." +
          C="&C." ') +
        KEYSIZE(2048) +
        NADATE(05/01/30) +
        LABLCERT(&LOCALCA) +
        KEYUSAGE('CERTSIGN')

/* Connect Zowe's local CA authority to the keyring ................ */
  TSS ADD(&ZOWEUSER.) KEYRING(ZOWERING) LABLRING(&ZOWERING.) +
      RINGDATA(CERTAUTH,ZOWECA)

/* Create a certificate signed by local zowe's CA .................. */
   TSS GENCERT(&ZOWEUSER.) +
       DIGICERT(ZOWECERT) +
       SUBJECTN( +
         'CN="&CN. certificate" +
         OU="&OU." +
         O="&O." +
         L="&L." +
         SP="&SP." +
         C="&C." ') +
       KEYSIZE(2048) +
       NADATE(05/01/30) +
       LABLCERT(&LABEL.) +
       KEYUSAGE('HANDSHAKE') +
       ALTNAME('DOMAIN=&HOSTNAME') +
       SIGNWITH(CERTAUTH,ZOWECA)

/* Connect a Zowe's certificate with the keyring ................... */
   TSS ADD(&ZOWEUSER.) KEYRING(ZOWERING) +
       RINGDATA(&ZOWEUSER.,ZOWECERT) +
       USAGE(PERSONAL) DEFAULT

/* Option 1 - Default Option - END ................................. */
$$
//IFOPT1ED ENDIF
//*
//IFOPT2   IF (&OPTION EQ 2) THEN
//RUNOPT2  EXEC PGM=IKJEFT01,REGION=0M
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DDNAME=&PRODUCT
//TSS      DD DATA,DLM=$$,SYMBOLS=JCLONLY

/* Option 2 - BEGINNING ............................................ */
/* Connect a Zowe's certificate with the keyring ................... */
   TSS ADD(&ZOWEUSER.) KEYRING(ZOWERING) +
       RINGDATA(CERTSITE|userid,digicert) +
       USAGE(PERSONAL) DEFAULT

/* Option 2 - END .................................................. */
$$
//IFOPT2ED ENDIF
//*
//IFOPT3   IF (&OPTION EQ 3) THEN
//RUNOPT3  EXEC PGM=IKJEFT01,REGION=0M
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DDNAME=&PRODUCT
//TSS      DD DATA,DLM=$$,SYMBOLS=JCLONLY

/* Option 3 - BEGINNING ............................................ */
/* Import external certificate from data set ....................... */
   TSS ADD(&ZOWEUSER.) +
        DIGICERT(ZOWECERT) +
        DCDSN(&DSNAME.) +
        LABLCERT(&LABEL.) +
        PKCSPASS('&PKCSPASS.') +
        TRUST

/* Connect a Zowe's certificate with the keyring ................... */
   TSS ADD(&ZOWEUSER.) KEYRING(ZOWERING) +
       RINGDATA(&ZOWEUSER.,ZOWECERT) +
       USAGE(PERSONAL) DEFAULT

/* Option 3 - END .................................................. */
$$
//IFOPT3ED ENDIF
//*
//IFZWCA   IF (&IFZOWECA EQ 1) THEN
//RUNZWCA  EXEC PGM=IKJEFT01,REGION=0M
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DDNAME=&PRODUCT
//TSS      DD DATA,DLM=$$,SYMBOLS=JCLONLY

/* Connect all CAs of the Zowe certificate's signing chain with the  */
/* keyring ......................................................... */
   TSS ADD(&ZOWEUSER.) KEYRING(ZOWERING) LABLRING(&ZOWERING.) +
       RINGDATA(CERTAUTH,&ITRMZWCA.) USAGE(CERTAUTH)

   TSS ADD(&ZOWEUSER.) KEYRING(ZOWERING) LABLRING(&ZOWERING.) +
       RINGDATA(CERTAUTH,&ROOTZWCA.) USAGE(CERTAUTH)
$$
//IFZWCAED ENDIF
//*
//IFZFCA   IF (&IFROZFCA EQ 1) THEN
//RUNZFCA  EXEC PGM=IKJEFT01,REGION=0M
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DDNAME=&PRODUCT
//TSS      DD DATA,DLM=$$,SYMBOLS=JCLONLY

/* Connect the z/OSMF root CA signed by a recognized certificate ... */
/* authority (CA) with the keyring ................................. */
   TSS ADD(&ZOWEUSER.) KEYRING(ZOWERING) LABLRING(&ZOWERING.) +
       RINGDATA(CERTAUTH,&ROOTZFCA.) USAGE(CERTAUTH)
$$
//IFZFCAED ENDIF
//*
//COMTSS   EXEC PGM=IKJEFT01,REGION=0M
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DDNAME=&PRODUCT
//TSS      DD DATA,DLM=$$,SYMBOLS=JCLONLY

/* A common part for all options starts here ....................... */
/* Create jwt secret ............................................... */
   TSS GENCERT(&ZOWEUSER.) +
      DIGICERT(ZOWEJWT) +
      SUBJECTN( +
        'CN="&CN. JWT" +
        OU="&OU." +
        O="&O." +
        L="&L." +
        SP="&SP." +
        C="&C." ') +
      KEYSIZE(2048) +
      NADATE(05/01/30) +
      LABLCERT(&JWTLABEL.)

/* Connect jwt secret to the keyring ............................... */
  TSS ADD(&ZOWEUSER.) KEYRING(ZOWERING) LABLRING(&ZOWERING.) +
      RINGDATA(&ZOWEUSER.,ZOWEJWT) USAGE(PERSONAL)

/* Allow ZOWEUSER to access keyring ................................ */
  TSS PERMIT(&ZOWEUSER.) IBMFAC(IRR.DIGTCERT.LISTRING) ACCESS(READ)

/* List the keyring ................................................ */
  TSS LIST(&ZOWEUSER.) KEYRING(ZOWERING) LABLRING(&ZOWERING.)

/* Common part - END ............................................... */
/* only the last RC is returned, this command ensures it is a 0      */
PROFILE
$$
//*
