//ZWENOSEC JOB <job parameters>
//*
//* This program and the accompanying materials are made available
//* under the terms of the Eclipse Public License v2.0 which
//* accompanies this distribution, and is available at
//* https://www.eclipse.org/legal/epl-v20.html
//*
//* SPDX-License-Identifier: EPL-2.0
//*
//* Copyright Contributors to the Zowe Project. 2018, 2020
//*
//*********************************************************************
//*
//* Zowe Open Source Project
//* This JCL can be used to define security permits for Zowe
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
//* 3) Update the SET ADMINGRP= statement to match the desired
//*    group name for Zowe administrators.
//*
//* 4) Update the SET STCGROUP= statement to match the desired
//*    group name for started tasks.
//*
//* 5) Update the SET ZOWEUSER= statement to match the desired
//*    user ID for the ZOWE started task.
//*
//* 6) Update the SET XMEMUSER= statement to match the desired
//*    user ID for the ZSS Cross Memory started task.
//*
//* 7) Update the SET AUXUSER= statement to match the desired
//*    user ID for the ZSS Auxilary Cross Memory started task.
//*
//* 8) Update the SET ZOWESTC= statement to match the desired
//*    Zowe started task name.
//*
//* 9) Update the SET XMEMSTC= statement to match the desired
//*    ZSS Cross Memory started task name.
//*
//* 10) Update the SET AUXSTC= statement to match the desired
//*     ZSS Auxilary Cross Memory started task name.
//*
//* 11) Update the SET HLQ= statement to match the desired
//*     Zowe data set high level qualifier.
//*
//* 12) Update the SET SYSPROG= statement to match the existing
//*     user ID or group used by z/OS system programmers.
//*
//* 13) Customize the commands in the DD statement that matches your
//*     security product so that they meet your system requirements.
//*
//* Note(s):
//*
//* 1. THE USER ID THAT RUNS THIS JOB MUST HAVE SUFFICIENT AUTHORITY
//*    TO ALTER SECURITY DEFINITONS
//*
//* 2. Remove users from the Zowe administrator group before removing
//*    the group itself.
//*
//* 3. This job WILL complete with return code 0.
//*    The results of each command must be verified after completion.
//*
//*********************************************************************
//         EXPORT SYMLIST=*
//*
//         SET PRODUCT=RACF          * RACF, ACF2, or TSS
//*                     12345678
//         SET ADMINGRP=ZWEADMIN     * group for Zowe administrators
//         SET STCGROUP=&ADMINGRP.   * group for Zowe started tasks
//         SET ZOWEUSER=ZWESVUSR     * userid for Zowe started task
//         SET XMEMUSER=ZWESIUSR     * userid for xmem started task
//         SET  AUXUSER=&XMEMUSER.   * userid for xmem AUX started task
//         SET  ZOWESTC=ZWESVSTC     * Zowe started task name
//         SET  XMEMSTC=ZWESISTC     * xmem started task name
//         SET   AUXSTC=ZWESASTC     * xmem AUX started task name
//         SET      HLQ=ZWE          * data set high level qualifier
//         SET  SYSPROG=&ADMINGRP.   * system programmer user ID/group
//*                     12345678
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

/* REMOVE ZOWE DATA SET PROTECTION ................................. */

/* general data set protection                                       */
  LISTDSD PREFIX(&HLQ.) ALL
  PERMIT '&HLQ..*.**' CLASS(DATASET) DELETE ID(&SYSPROG.)
  DELDSD '&HLQ..*.**'

/* HLQ stub                                                          */
  LISTGRP  &HLQ. ALL
  DELGROUP &HLQ.

  SETROPTS GENERIC(DATASET) REFRESH

/* REMOVE ZSS SERVER PERMISIONS .................................... */

/* permit ZSS to create a user's security environment                */
  RLIST  FACILITY BPX.DAEMON ALL
  PERMIT BPX.DAEMON CLASS(FACILITY) DELETE ID(&XMEMUSER.)

  RLIST  FACILITY BPX.SERVER ALL
  PERMIT BPX.SERVER CLASS(FACILITY) DELETE ID(&XMEMUSER.)

  SETROPTS RACLIST(FACILITY) REFRESH

/* REMOVE ZOWE SERVER PERMISIONS ................................... */

/* permit Zowe main server to use ZSS Cross Memory server            */
  RLIST  FACILITY ZWEX.IS ALL
  PERMIT ZWEX.IS CLASS(FACILITY) DELETE ID(&ZOWEUSER.)

  SETROPTS RACLIST(FACILITY) REFRESH

/* REMOVE STARTED TASKS ............................................ */

/* started task for ZOWE, main server                                */
  RLIST   STARTED &ZOWESTC..* ALL STDATA
  RDELETE STARTED &ZOWESTC..*

/* started task for ZSS Cross Memory server                          */
  RLIST   STARTED &XMEMSTC..* ALL STDATA
  RDELETE STARTED &XMEMSTC..*

/* started task for ZSS Auxilary Cross Memory server                 */
  RLIST   STARTED &AUXSTC..* ALL STDATA
  RDELETE STARTED &AUXSTC..*

/* userid for ZOWE, main server                                      */
  LISTUSER &ZOWEUSER. OMVS
  DELUSER  &ZOWEUSER.  

/* userid for ZSS Cross Memory server                                */
  LISTUSER &XMEMUSER. OMVS
  DELUSER  &XMEMUSER. 

/* userid for ZSS Auxilary Cross Memory server                       */
  LISTUSER &AUXUSER. OMVS
  DELUSER  &AUXUSER. 

  SETROPTS RACLIST(STARTED) REFRESH

/* REMOVE ADMINISTRATORS ........................................... */

/* group for administrators                                          */
  LISTGRP  &ADMINGRP. OMVS
  /* REMOVE (userid,userid,...) GROUP(&ADMINGRP.) */
  DELGROUP &ADMINGRP.

/* ................................................................. */
/* only the last RC is returned, this comment ensures it is a 0      */
$$
//*
//*********************************************************************
//*
//* ACF2 ONLY, customize to meet your system requirements
//*
//ACF2     DD DATA,DLM=$$,SYMBOLS=JCLONLY

/*TODO ACF2 remove security setup                                    */

/* ................................................................. */
/* only the last RC is returned, this comment ensures it is a 0      */
$$
//*
//*********************************************************************
//*
//* Top Secret ONLY, customize to meet your system requirements
//*
//TSS      DD DATA,DLM=$$,SYMBOLS=JCLONLY

/*TODO TSS remove security setup                                     */

/* ................................................................. */
/* only the last RC is returned, this comment ensures it is a 0      */
$$
//*
