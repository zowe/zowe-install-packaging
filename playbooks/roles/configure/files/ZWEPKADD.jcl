//ZWEPKADD JOB
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
//* This JCL adds testing client certificate to ACF2
//*
//*********************************************************************
//         EXPORT SYMLIST=*
//*
//         SET ZOWEUSER=ZWESVUSR.JWTSCRT  * userid for Zowe started task
//*                     12345678
//*
//*      * Zowe's certificate Label (PKCS12)
//         SET   LABEL=JWTCERT
//*
//* ACF2 ONLY -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
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
//SYSTSIN  DD DDNAME=ACF2
//*
//*********************************************************************
//*
//* ACF2 ONLY, customize to meet your system requirements
//*
//ACF2     DD DATA,DLM=$$,SYMBOLS=JCLONLY
ACF
  SET PROFILE(USER) DIV(CERTDATA)
  P11TOKEN ADD TOKEN(ZWETOKEN)
  P11TOKEN BIND TOKEN(ZWETOKEN) CERTDATA(&ZOWEUSER)
  P11TOKEN LIST TOKEN(ZWETOKEN)
$$
//*

