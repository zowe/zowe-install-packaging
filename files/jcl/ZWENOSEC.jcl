//ZWENOSEC JOB
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
//* This JCL can be used to remove security permits for Zowe
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
//* 4) Update the SET STCGRP= statement to match the desired
//*    group name for started tasks.
//*
//* 5) Update the SET ZOWEUSER= statement to match the desired
//*    user ID for the ZOWE started task.
//*
//* 6) Update the SET XMEMUSER= statement to match the desired
//*    user ID for the XMEM Cross Memory started task.
//*
//* 7) Update the SET AUXUSER= statement to match the desired
//*    user ID for the XMEM Auxilary Cross Memory started task.
//*
//* 8) Update the SET ZOWESTC= statement to match the desired
//*    Zowe started task name.
//*
//* 9) Update the SET XMEMSTC= statement to match the desired
//*    XMEM Cross Memory started task name.
//*
//* 10) Update the SET AUXSTC= statement to match the desired
//*     XMEM Auxilary Cross Memory started task name.
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
//         SET   STCGRP=&ADMINGRP.   * group for Zowe started tasks
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
//* Top Secret ONLY -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
//*                     12345678
//         SET ADMINDEP=SYSPDEPT     * department owning admin group
//*                     12345678
//*
//* end Top Secret ONLY -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
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

/* - The sample commands assume that EGN (Enhanced Generic Naming)   */
/*   is active, which allows the usage of ** to represent any number */
/*   of qualifiers in the DATASET class. Substitute *.** with * if   */
/*   EGN is not active on your system.                               */

/* remove general data set protection                                */
  LISTDSD PREFIX(&HLQ.) ALL
  PERMIT '&HLQ..*.**' CLASS(DATASET) DELETE ID(&SYSPROG.)
  DELDSD '&HLQ..*.**'

/* remove HLQ stub                                                   */
  LISTGRP  &HLQ.
  DELGROUP &HLQ.

  SETROPTS GENERIC(DATASET) REFRESH

/* REMOVE ZOWE SERVER PERMISIONS ................................... */

/* remove permit to use XMEM Cross Memory server                     */
  RLIST  FACILITY ZWES.IS ALL
  PERMIT ZWES.IS CLASS(FACILITY) DELETE ID(&ZOWEUSER.)

/* remove permit to create a user's security environment             */
  RLIST  FACILITY BPX.DAEMON ALL
  PERMIT BPX.DAEMON CLASS(FACILITY) DELETE ID(&ZOWEUSER.)

  RLIST  FACILITY BPX.SERVER ALL
  PERMIT BPX.SERVER CLASS(FACILITY) DELETE ID(&ZOWEUSER.)

/* remove permit to set jobname                                      */
  RLIST  FACILITY BPX.JOBNAME ALL
  PERMIT BPX.JOBNAME CLASS(FACILITY) DELETE ID(&ZOWEUSER.)

/* remove permit to write persistent data                            */
  RLIST  UNIXPRIV SUPERUSER.FILESYS ALL
  PERMIT SUPERUSER.FILESYS CLASS(UNIXPRIV) DELETE ID(&ZOWEUSER.)

  SETROPTS RACLIST(FACILITY) REFRESH
  SETROPTS RACLIST(UNIXPRIV) REFRESH

/* REMOVE STARTED TASKS ............................................ */

/* remove userid for ZOWE main server                                */
  LISTUSER &ZOWEUSER. OMVS
  DELUSER  &ZOWEUSER.

/* remove userid for XMEM Cross Memory server                        */
  LISTUSER &XMEMUSER. OMVS
  DELUSER  &XMEMUSER.

/* comment out if &AUXUSER matches &XMEMUSER (default), expect       */
/*   warning messages otherwise                                      */
/* remove userid for XMEM auxilary cross memory server               */
  LISTUSER &AUXUSER. OMVS
  DELUSER  &AUXUSER.

/* comment out if &STCGRP matches &ADMINGRP (default), expect        */
/*   warning messages otherwise                                      */
/* remove group for started tasks                                    */
  LISTGRP  &STCGRP. OMVS
  DELGROUP &STCGRP.

/* remove started task for ZOWE main server                          */
  RLIST   STARTED &ZOWESTC..* ALL STDATA
  RDELETE STARTED &ZOWESTC..*

/* remove started task for XMEM Cross Memory server                  */
  RLIST   STARTED &XMEMSTC..* ALL STDATA
  RDELETE STARTED &XMEMSTC..*

/* remove started task for XMEM Auxilary Cross Memory server         */
  RLIST   STARTED &AUXSTC..* ALL STDATA
  RDELETE STARTED &AUXSTC..*

  SETROPTS RACLIST(STARTED) REFRESH

/* REMOVE ADMINISTRATORS ........................................... */

/* uncomment to remove user IDs from the &ADMINGRP group             */
/* REMOVE (userid,userid,...) GROUP(&ADMINGRP.)                      */

/* remove group for administrators                                   */
  LISTGRP  &ADMINGRP. OMVS
  DELGROUP &ADMINGRP.

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
*
* DELETE ADMINISTRATORS ...........................................
*
* group for administrators
*
SET PROFILE(GROUP) DIV(OMVS)
DELETE &ADMINGRP.
F ACF2,REBUILD(GRP),CLASS(P)
*
*
SET LID
SET PROFILE(USER) DIV(OMVS)
DELETE &ZOWEUSER.
F ACF2,REBUILD(USR),CLASS(P),DIVISION(OMVS)
*
SET LID
SET PROFILE(USER) DIV(OMVS)
DELETE &XMEMUSER.
F ACF2,REBUILD(USR),CLASS(P),DIVISION(OMVS)
*
* remove userid for ZOWE main server (XMEMSTC,AUXSTC have same user id)
SET LID
LIST &ZOWEUSER
DELETE &ZOWEUSER.
*
*
* remove userid for XMEM Cross Memory server                        */
SET LID
LIST &XMEMUSER
DELETE &XMEMUSER.
*
*
*****
*
* Delete  task for ZOWE main server
*
SET CONTROL(GSO)
LIST LIKE(STC.Z-)
DELETE STC.&ZOWESTC.
F ACF2,REFRESH(STC)
*
* started task for XMEM cross memory server
*
SET CONTROL(GSO)
DELETE STC.&XMEMSTC.
F ACF2,REFRESH(STC)
*
* started task for XMEM auxilary cross memory server
*
SET CONTROL(GSO)
DELETE STC.&AUXSTC.
F ACF2,REFRESH(STC)
*
* Remove Zowe main server
*
SET RESOURCE(FAC)
RECKEY BPX DEL(DAEMON ROLE(&STCGRP.) SERVICE(UPDATE) ALLOW)
RECKEY BPX DEL(SERVER ROLE(&STCGRP.) SERVICE(UPDATE) ALLOW)
RECKEY BPX DEL(JOBNAME ROLE(&STCGRP.) SERVICE(READ) ALLOW)
* Remove Zowe main server
RECKEY ZWES DEL(IS ROLE(&STCGRP.) SERVICE(READ) ALLOW)
F ACF2,REBUILD(FAC)
* Remove UNI
*
SET RESOURCE(UNI)
DELETE SUPERUSER.FILESYS
*
F ACF2,REBUILD(UNI)
*  Remove  data set protection
SET RULE
LIST &HLQ.
DELETE &HLQ.
*
$$
//*
//*********************************************************************
//*
//* Top Secret ONLY, customize to meet your system requirements
//*
//TSS      DD DATA,DLM=$$,SYMBOLS=JCLONLY

/* REMOVE ZOWE DATA SET PROTECTION ................................. */
/* removE general data set protection                                */
TSS WHOHAS DATASET(&HLQ)
TSS REVOKE(ALL) DATASET(&HLQ..)
TSS REVOKE(&SYSPROG) DATASET(&HLQ..)
TSS REMOVE(&ADMINDEP) DATASET(&HLQ..)

/* REMOVE ZOWE SERVER PERMISIONS ................................... */

/* remove permit to use XMEM Cross Memory server                     */
TSS WHOHAS IBMFAC(ZWES.IS)
TSS REVOKE(&ZOWEUSER) IBMFAC(ZWES.IS)

/* remove permit to create a user's security environment             */
TSS WHOHAS IBMFAC(BPX.DAEMON)
TSS REVOKE(&ZOWEUSER) IBMFAC(BPX.DAEMON)
TSS WHOHAS IBMFAC(BPX.SERVER)
TSS REVOKE(&ZOWEUSER) IBMFAC(BPX.SERVER)

/* remove permit to set jobname                                      */
TSS WHOHAS IBMFAC(BPX.JOBNAME)
TSS REVOKE(&ZOWEUSER) IBMFAC(BPX.JOBNAME)

/* remove permit to write persistent data                            */
TSS WHOHAS UNIXPRIV(SUPERUSER.FILESYS)
TSS REVOKE(&ZOWEUSER) UNIXPRIV(SUPERUSER.FILESYS)

/* REMOVE STARTED TASKS ............................................ */

/* remove userid for ZOWE main server                                */
TSS LIST(&ZOWEUSER)
TSS DELETE(&ZOWEUSER)

/* remove userid for XMEM Cross Memory server                        */
TSS LIST(&XMEMUSER)
TSS DELETE(&XMEMUSER)

/* comment out if &AUXUSER matches &XMEMUSER (default), expect       */
/*   warning messages otherwise                                      */
/* remove userid for XMEM auxilary cross memory server               */
TSS LIST(&AUXUSER)
TSS DELETE(&AUXUSER)

/* comment out if &STCGRP matches &ADMINGRP (default), expect        */
/*   warning messages otherwise                                      */
/* remove group for started tasks                                    */
TSS LIST(&STCGRP)
TSS DELETE(&STCGRP)

/* remove started task for ZOWE main server                          */
TSS LIST(STC)
TSS REMOVE(STC) PROCNAME(&ZOWESTC)

/* remove started task for XMEM Cross Memory server                  */
TSS LIST(STC)
TSS REMOVE(STC) PROCNAME(&XMEMSTC)

/* remove started task for XMEM Auxilary Cross Memory server         */
TSS LIST(STC)
TSS REMOVE(STC) PROCNAME(&AUXSTC)

/* REMOVE ADMINISTRATORS ........................................... */

/* uncomment to remove user IDs from the &ADMINGRP group             */
/* TSS REMOVE (userid) GROUP(&ADMINGRP.)                             */
/* remove group for administrators                                   */
TSS LIST(&ADMINGRP)
TSS DELETE(&ADMINGRP)
/* ................................................................. */
/* only the last RC is returned, this command ensures it is a 0      */
PROFILE
$$
//*
