//ZWESECUR JOB <job parameters>
//*********************************************************************
//* This program and the accompanying materials are made available    *
//* under the terms of the Eclipse Public License v2.0 which          *
//* accompanies this distribution, and is available at                *
//* https://www.eclipse.org/legal/epl-v20.html                        *
//*                                                                   *
//* SPDX-License-Identifier: EPL-2.0                                  *
//*                                                                   *
//* 5698-ZWE Copyright Contributors to the Zowe Project. 2019, 2019   *
//*********************************************************************
//*                                                                   *
//* Zowe Open Source Project                                          *
//* This JCL can be used to define security permits for Zowe          *
//*                                                                   *
//*                                                                   *
//* CAUTION: This is neither a JCL procedure nor a complete job.      *
//* Before using this JCL, you will have to make the following        *
//* modifications:                                                    *
//*                                                                   *
//* 1) Add job name and job parameters to the JOB statement, to       *
//*    meet your system requirements.                                 *
//*                                                                   *
//* 2) Update the SET PRODUCT= statement to match your security       *
//*    product.                                                       *
//*                                                                   *
//* 3) Customize the commands in the DD statement that matches your   *
//*    security product so that they meet your system requirements.   *
//*                                                                   *
//* Note(s):                                                          *
//*                                                                   *
//* 1. THE USER ID THAT RUNS THIS JOB MUST HAVE SUFFICIENT AUTHORITY  *
//*    TO ALTER SECURITY DEFINITONS                                   *
//*                                                                   *
//* 2. This job WILL complete with return code 0.                     *
//*    The results of each step must be verified after completion.    *
//*                                                                   *
//*********************************************************************
//*
//         SET PRODUCT=RACF          * RACF, ACF2, or TSS
//*
//*********************************************************************
//*
//* CREATE TEMP REXX TO BE USED AS COMMENT CHARACTER FOR BATCH TSO
//* - no customization needed
//*
//COMMENT  EXEC PGM=IEBGENER
//SYSPRINT DD SYSOUT=*
//SYSIN    DD DUMMY
//SYSUT2   DD DISP=(NEW,PASS),DSN=&&COMMENT(#),UNIT=SYSALLDA,
//            SPACE=(TRK,(1,1,1)),DCB=(RECFM=FB,LRECL=80)
//SYSUT1   DD DATA,DLM=$$
 /* REXX */
 /* COMMENT COMMAND TO BE USED IN BATCH TSO */
 NOP
 EXIT 0
$$
//*
//* EXECUTE COMMANDS FOR SELECTED SECURITY PRODUCT
//*
//RUN      EXEC PGM=IKJEFT01,REGION=0M
//SYSEXEC  DD DISP=(SHR,PASS),DSN=&&COMMENT
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DDNAME=&PRODUCT
//*
//*********************************************************************
//*
//* RACF ONLY, customize to meet your system requirements
//*
//RACF     DD *
#
#  ACTIVATE REQUIRED RACF SETTINGS AND CLASSES
#  * uncomment the activation statements for the classes that are not
#    active yet
#
#  display current settings
# SETROPTS LIST

#  activate facility class for Zowe ZSS profiles
# SETROPTS GENERIC(FACILITY)
# SETROPTS CLASSACT(FACILITY) RACLIST(FACILITY)

#  activate started task class
# SETROPTS GENERIC(STARTED)
# RDEFINE STARTED ** STDATA(USER(=MEMBER) GROUP(STCGROUP) TRACE(YES))
# SETROPTS CLASSACT(STARTED) RACLIST(STARTED)

#  show results .......................................................
  SETROPTS LIST

#  DEFINE STARTED TASK ................................................
#  * (optional) change STCGROUP to the group name for started tasks
#  * (optional) change STCZWE to the user ID of the ZOWE started task
#  * (optional) change STCZSS to the user ID of the ZSS started task
#  * (optional) change "ZOWESVR." to the name of the ZOWE started task
#  * (optional) change "ZWESIS01." to the name of the ZSS started task
#
#  Notes:
#  * ensure that user ID's are protected with the NOPASSWORD keyword
#  * The sample commands assume automatic generation of UID and GID is
#    enabled. If not, replace AUTOGID with GID(gid) and AUTOUID with
#    UID(uid), where "gid" and "uid" are a valid z/OS UNIX group and
#    user ID respectively.

#  group for started tasks
  LISTGRP  STCGROUP OMVS
  ADDGROUP STCGROUP
  ALTGROUP STCGROUP OMVS(AUTOGID) -
   DATA('STARTED TASK GROUP WITH OMVS SEGEMENT')

#  userid for ZOWE, main server
  LISTUSER STCZWE OMVS
  ADDUSER  STCZWE -
   NOPASSWORD -
   DFLTGRP(STCGROUP) -
   OMVS(HOME(/tmp) PROGRAM(/bin/sh) AUTOUID) -
   NAME('ZOWE') -
   DATA('ZOWE SERVER')

#  userid for ZSS, cross memory server
  LISTUSER STCZSS OMVS
  ADDUSER  STCZSS -
   NOPASSWORD -
   DFLTGRP(STCGROUP) -
   OMVS(HOME(/tmp) PROGRAM(/bin/sh) AUTOUID) -
   NAME('ZOWE ZSS') -
   DATA('ZOWE ZSS CROSS MEMORY SERVER')

#  started task for ZOWE, main server
  RLIST   STARTED ZOWESVR.* ALL STDATA
  RDEFINE STARTED ZOWESVR.* -
   STDATA(USER(STCZWE) GROUP(STCGROUP) TRUSTED(NO)) -
   DATA('ZOWE SERVER')

#  started task for ZSS, cross memory server
  RLIST   STARTED ZWESIS01.* ALL STDATA
  RDEFINE STARTED ZWESIS01.* -
   STDATA(USER(STCZSS) GROUP(STCGROUP) TRUSTED(NO)) -
   DATA('ZOWE ZSS CROSS MEMORY SERVER')

  SETROPTS RACLIST(STARTED) REFRESH

#  show results .......................................................
  LISTGRP  STCGROUP OMVS
  LISTUSER STCZSS   OMVS
  RLIST STARTED ZWESIS01.* ALL STDATA

#  DEFINE ACCESS CONTROL TO ZSS SERVICES ..............................
#
#  permit Zowe server to use ZSS, cross memory server
  RLIST   FACILITY ZWESIS ALL
  RDEFINE FACILITY ZWESIS UACC(NONE)
  PERMIT ZWESIS CLASS(FACILITY) ACCESS(READ) ID(STCZWE)

  SETROPTS RACLIST(FACILITY) REFRESH

#  show results .......................................................
  RLIST   FACILITY ZWESIS ALL

#  only the last RC is returned, this comment ensures it's a 0
//*
//*********************************************************************
//*
//* ACF2 ONLY, customize to meet your system requirements
//*
//ACF2     DD *
#  DEFINE STARTED TASK ................................................
#  * (optional) change STCGROUP to the group name for started tasks
#  * (optional) change STCZWE to the user ID of the ZOWE started task
#  * (optional) change STCZSS to the user ID of the ZSS started task
#  * (optional) change "ZOWESVR*" to the name of the ZOWE started task
#  * (optional) change "ZWESIS*" to the name of the ZSS started task
#
#  group for started tasks
# TODO ACF2 group for started tasks

#  userid for ZOWE, main server
  INSERT STCZWE GROUP(STCGROUP) SET PROFILE(USER) +
   DIV(OMVS) INSERT STCZWE UID(STCZSS)

  INSERT STCZSS GROUP(STCGROUP) SET PROFILE(USER) +
   DIV(OMVS) INSERT STCZSS UID(STCZSS)

# operator command F ACF2,REBUILD(USR),CLASS(P)
# operator command F ACF2,OMVS

#  started task for ZOWE, main server
  SET CONTROL(GSO)
  INSERT STC.ZOWESVR**** LOGONID(STCZWE) GROUP(STCGROUP) +
   STCID(ZOWESVR****)

#  started task for ZSS, cross memory server
  SET CONTROL(GSO)
  INSERT STC.ZWESIS***** LOGONID(STCZSS) GROUP(STCGROUP) +
   STCID(ZWESIS*****)

# operator command F ACF2,REFRESH(STC)

#  DEFINE ACCESS CONTROL TO ZSS SERVICES ..............................
#
#  permit Zowe server to use ZSS, cross memory server
# TODO ACF2 permit Zowe server to use ZSS, cross memory server

#  only the last RC is returned, this comment ensures it's a 0
//*
//*********************************************************************
//*
//* Top Secret ONLY, customize to meet your system requirements
//*
//TSS      DD *
#  DEFINE STARTED TASK ................................................
#  * (optional) change STCGROUP to the group name for started tasks
#  * (optional) change STCZWE to the user ID of the ZOWE started task
#  * (optional) change STCZSS to the user ID of the ZSS started task
#  * (optional) change "ZOWESVR." to the name of the ZOWE started task
#  * (optional) change "ZWESIS01." to the name of the ZSS started task
#
#  group for started tasks
# TODO TSS group for started tasks

#  userid for ZOWE, main server
  TSS ADDTO(STCZWE) DFLTGRP(STCGROUP) UID(110)

#  userid for ZSS, cross memory server
  TSS ADDTO(STCZSS) DFLTGRP(STCGROUP) UID(111)

#  started task for ZOWE, main server
  TSS ADD(STC) PROCNAME(ZOWESVR*) ACID(STCZWE)

#  started task for ZSS, cross memory server
  TSS ADD(STC) PROCNAME(ZWESIS01*) ACID(STCZSS)

#  DEFINE ACCESS CONTROL TO ZSS SERVICES ..............................
#
#  permit Zowe server to use ZSS, cross memory server
  TSS ADDTO(STCZWE) IBMFAC(ZWESIS)

#  only the last RC is returned, this comment ensures it's a 0
//*
