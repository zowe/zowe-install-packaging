//*
//* This program and the accompanying materials are made available
//* under the terms of the Eclipse Public License v2.0 which
//* accompanies this distribution, and is available at
//* https://www.eclipse.org/legal/epl-v20.html
//*
//* SPDX-License-Identifier: EPL-2.0
//*
//* Copyright Contributors to the Zowe Project. 2018, 2019
//*
//*********************************************************************
//*
//* Zowe Open Source Project
//* This JCL procedure is used to start the ZOWE ZSS server (Z Secure
//* Services)
//*
//* Invocation arguments:
//* NAME - Name of this server (maximum 16 characters)
//*        sample default: ZWESIS_STD
//* HLQ  - High level qualifier of the SZWEAUTH load library
//*        sample default: ZOWE
//* CFG  - Name of data set holding configuration member ZWESIPxx
//*        sample default: ZOWE.#CUST.SAMPLIB
//* MEM  - Suffix of the ZWESIPxx member (maximum 2 characters)
//*        sample default: 00
//* PRM  - Provide additional startup arguments
//*        sample default: ''
//*        COLD  - Cold start (reset server state)
//*                DO NOT USE WITHOUT CONSULTING WITH SUPPORT.
//*        DEBUG - Debug mode
//*
//* Note(s):
//*
//* 1. The user ID assigned to this server needs special security
//*    permits. See samle job SZWESAMP(ZWESECUR) for details.
//*
//* 2. The SZWEAUTH library must be APF authorized.
//*
//* 3. The started task MUST use a STEPLIB DD statement to declare
//*    the ZSS Server load library name. This is required so that the
//*    appropriate version of the software is loaded correctly.
//*    Do NOT add the load library data set to the system LNKLST or
//*    LPALST concatenations.
//*
//* 4. By default, the server will read its parameters from the
//*    ZWESIPxx member in the PARMLIB DD statement. Comment out the
//*    CFG PROC argument and the PARMLIB DD If you want to use your
//*    system defined parmlib concatenation to find ZWISIPxx.
//*
//*********************************************************************
//*
//* ZOWE ZSS SERVER (Z Secure Services)
//*
//ZOWEZSS  PROC RGN=0M,
//            PRM=,
//            NAME='ZWESIS_STD',
//            HLQ=ZOWE,
//            CFG=ZOWE.#CUST.SAMPLIB,
//            MEM=00
//*
//********************************************************************
//*
//* Zowe Open Source Project
//* Sample STC JCL for the Zowe ZSS Cross-Memory Server
//*
//* 1. Run-time parameters
//*
//*   COLD  - Cold start
//*           RESET SERVER STATE.
//*           DO NOT USE WITHOUT CONSULTING WITH SUPPORT.
//*
//*           EXAMPLE: PARM='COLD'
//*   DEBUG - Debug mode
//*           EXAMPLE: PARM='DEBUG'
//*   NAME  - Name of this server
//*           ZWESIS_STD is the default name, the max length is 16.
//*           example: NAME='ZWESIS_02'
//*   MEM   - Suffix of the ZWESIPxx member
//*           00 is the default value.
//*           example: MEM=02
//*
//* 2. STEPLIB data set name
//*
//* Verify and/or change the name of the STEPLIB data set
//*
//* The started task MUST use a STEPLIB DD statement to declare
//* the ZSS Cross-Memory Server load library name. This is required
//* so that the appropriate version of the software is loaded
//* correctly. Do NOT add the load library data set to the system
//* LNKLST or LPALST concatenations.
//*
//* 3. PARMLIB DD
//*
//* Verify and/or change the name of the PARMLIB data set
//*
//* By default, the server will read its parameters from the
//* ZWESIPxx member in the PARMLIB DD statement. If you want to use
//* your system defined parmlib, comment out the PARMLIB DD.
//*
//********************************************************************/
//ZWESIS01 EXEC PGM=ZWESIS01,REGION=&RGN,              TIME=NOLIMIT,
//            PARM='NAME=&NAME,MEM=&MEM,&PRM'
//STEPLIB  DD DISP=SHR,DSN=&HLQ..SZWEAUTH
//PARMLIB  DD DISP=SHR,DSN=&CFG
//SYSPRINT DD SYSOUT=*
//*
