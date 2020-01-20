//ZWESECUR JOB                                                                  
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
//* 6) Update the SET ZSSUSER= statement to match the desired                   
//*    user ID for the ZSS started task.                                        
//*                                                                             
//* 7) Update the SET AUXUSER= statement to match the desired                   
//*    user ID for the ZSS Auxilary started task.                               
//*                                                                             
//* 8) Update the SET ZOWESTC= statement to match the desired                   
//*    Zowe started task name.                                                  
//*                                                                             
//* 9) Update the SET ZSSSTC= statement to match the desired                    
//*    ZSS started task name.                                                   
//*                                                                             
//* 10) Update the SET AUXSTC= statement to match the desired                   
//*    ZSS Auxilary started task name.                                          
//*                                                                             
//* 11) Customize the commands in the DD statement that matches your            
//*    security product so that they meet your system requirements.             
//*                                                                             
//* Note(s):                                                                    
//*                                                                             
//* 1. THE USER ID THAT RUNS THIS JOB MUST HAVE SUFFICIENT AUTHORITY            
//*    TO ALTER SECURITY DEFINITONS                                             
//*                                                                             
//* 2. The Zowe started task user ID (variable ZOWEUSER) must be able           
//*    to write persistent data in the zlux-app-server/deploy directory         
//*    structure. This sample JCL makes the Zowe started task part of           
//*    the ZOwe administrator group (SET STCGROUP=&ADMINGRP. statement)         
//*    to achieve this goal. Another solution, which is provided                
//*    commented out, is giving the Zowe started task CONTROL access to         
//*    the UNIXPRIV SUPERUSER.FILESYS profile.                                  
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
//         SET ZSSUSER=ZWESIUSR      * userid for xmem started task             
//         SET  AUXUSER=&ZSSUSER.    * userid for xmem AUX started task         
//         SET  ZOWESTC=ZWESVSTC     * Zowe started task name                   
//         SET  ZSSSTC=ZWESISTC      * xmem started task name                   
//         SET   AUXSTC=ZWESASTC     * xmem AUX started task name               
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
                                                                                
/* ACTIVATE REQUIRED RACF SETTINGS AND CLASSES ..................... */         
                                                                                
/* - uncomment the activation statements for the classes that are    */         
/*   not active yet                                                  */         
                                                                                
/* display current settings                                          */         
/*SETROPTS LIST                                                      */         
                                                                                
/* activate FACILITY class for z/OS UNIX & Zowe ZSS profiles         */         
  SETROPTS GENERIC(FACILITY)                                                    
  SETROPTS CLASSACT(FACILITY) RACLIST(FACILITY)                                 
                                                                                
/** uncomment to use SUPERUSER.FILESYS, see JCL comments             */         
/** activate UNIXPRIV class for z/OS UNIX profiles                   */         
  SETROPTS GENERIC(UNIXPRIV)                                                    
  SETROPTS CLASSACT(UNIXPRIV) RACLIST(UNIXPRIV)                                 
                                                                                
/* activate started task class                                       */         
  SETROPTS GENERIC(STARTED)                                                     
  RDEFINE STARTED ** STDATA(USER(=MEMBER) GROUP(&STCGROUP.))                    
  SETROPTS CLASSACT(STARTED) RACLIST(STARTED)                                   
                                                                                
/* show results .................................................... */         
  SETROPTS LIST                                                                 
                                                                                
/* DEFINE ADMINISTRATORS ........................................... */         
                                                                                
/* - The sample commands assume automatic generation of GID is       */         
/*   enabled. If not, replace AUTOGID with GID(gid) , where "gid"    */         
/*   is a valid z/OS UNIX group.                                     */         
                                                                                
/* group for administrators                                          */         
  LISTGRP  &ADMINGRP. OMVS                                                      
  ADDGROUP &ADMINGRP.                                                           
  ALTGROUP &ADMINGRP. OMVS(AUTOGID) -                                           
   DATA('ZOWE ADMINISTRATORS')                                                  
                                                                                
/* DEFINE STARTED TASK ............................................. */         
                                                                                
/* - ensure that user IDs are protected with the NOPASSWORD keyword  */         
/* - The sample commands assume automatic generation of UID and GID  */         
/*   is enabled. If not, replace AUTOGID with GID(gid) and AUTOUID   */         
/*   with UID(uid), where "gid" and "uid" are a valid z/OS UNIX      */         
/*   group and user ID respectively.                                 */         
                                                                                
/** uncomment to use SUPERUSER.FILESYS, see JCL comments             */         
/** group for started tasks                                          */         
   LISTGRP  &STCGROUP. OMVS                                                     
   ADDGROUP &STCGROUP.                                                          
   ALTGROUP &STCGROUP. OMVS(AUTOGID) -                                          
    DATA('STARTED TASK GROUP WITH OMVS SEGEMENT')                               
                                                                                
/* userid for ZOWE, main server                                      */         
  LISTUSER &ZOWEUSER. OMVS                                                      
  ADDUSER  &ZOWEUSER. -                                                         
   NOPASSWORD -                                                                 
   DFLTGRP(&STCGROUP.) -                                                        
   OMVS(HOME(/tmp) PROGRAM(/bin/sh) AUTOUID) -                                  
   NAME('ZOWE SERVER') -                                                        
   DATA('ZOWE MAIN SERVER')                                                     
                                                                                
/* userid for ZSS, cross memory server                               */         
  LISTUSER &ZSSUSER. OMVS                                                       
  ADDUSER  &ZSSUSER. -                                                          
   NOPASSWORD -                                                                 
   DFLTGRP(&STCGROUP.) -                                                        
   OMVS(HOME(/tmp) PROGRAM(/bin/sh) AUTOUID) -                                  
   NAME('ZOWE ZSS SERVER') -                                                    
   DATA('ZOWE ZSS CROSS MEMORY SERVER')                                         
                                                                                
/* userid for ZSS auxilary cross memory server                       */         
  LISTUSER &AUXUSER. OMVS                                                       
  ADDUSER  &AUXUSER. -                                                          
   NOPASSWORD -                                                                 
   DFLTGRP(&STCGROUP.) -                                                        
   OMVS(HOME(/tmp) PROGRAM(/bin/sh) AUTOUID) -                                  
   NAME('ZOWE ZSS AUX SERVER') -                                                
   DATA('ZOWE ZSS AUX CROSS MEMORY SERVER')                                     
                                                                                
/* started task for ZOWE, main server                                */         
  RLIST   STARTED &ZOWESTC..* ALL STDATA                                        
  RDEFINE STARTED &ZOWESTC..* -                                                 
   STDATA(USER(&ZOWEUSER.) GROUP(&STCGROUP.) TRUSTED(NO)) -                     
   DATA('ZOWE MAIN SERVER')                                                     
                                                                                
/* started task for ZSS, cross memory server                         */         
  RLIST   STARTED &ZSSSTC..* ALL STDATA                                         
  RDEFINE STARTED &ZSSSTC..* -                                                  
   STDATA(USER(&ZSSUSER.) GROUP(&STCGROUP.) TRUSTED(NO)) -                      
   DATA('ZOWE ZSS CROSS MEMORY SERVER')                                         
                                                                                
/* started task for ZSS auxilary cross memory server                 */         
  RLIST   STARTED &AUXSTC..* ALL STDATA                                         
  RDEFINE STARTED &AUXSTC..* -                                                  
   STDATA(USER(&AUXUSER.) GROUP(&STCGROUP.) TRUSTED(NO)) -                      
   DATA('ZOWE ZSS AUX CROSS MEMORY SERVER')                                     
                                                                                
  SETROPTS RACLIST(STARTED) REFRESH                                             
                                                                                
/* show results .................................................... */         
  LISTGRP  &STCGROUP. OMVS                                                      
  LISTUSER &ZOWEUSER. OMVS                                                      
  LISTUSER &ZSSUSER.  OMVS                                                      
  LISTUSER &AUXUSER.  OMVS                                                      
  RLIST STARTED &ZOWESTC..* ALL STDATA                                          
  RLIST STARTED &ZSSSTC..*  ALL STDATA                                          
  RLIST STARTED &AUXSTC..*  ALL STDATA                                          
                                                                                
/* DEFINE ZOWE SERVER PERMISIONS ................................... */         
                                                                                
/* permit Zowe main server to use ZSS, cross memory server           */         
  RLIST   FACILITY ZWES.IS ALL                                                  
  RDEFINE FACILITY ZWES.IS UACC(NONE)                                           
  PERMIT ZWES.IS CLASS(FACILITY) ACCESS(READ) ID(&ZOWEUSER.)                    
                                                                                
  SETROPTS RACLIST(FACILITY) REFRESH                                            
                                                                                
/** uncomment to use SUPERUSER.FILESYS, see JCL comments             */         
/** permit Zowe main server to write persistent data                 */         
   RLIST   UNIXPRIV SUPERUSER.FILESYS ALL                                       
   RDEFINE UNIXPRIV SUPERUSER.FILESYS UACC(NONE)                                
   PERMIT SUPERUSER.FILESYS CLASS(UNIXPRIV) ACCESS(CONTROL) -                   
    ID(&ZOWEUSER.)                                                              
                                                                                
   SETROPTS RACLIST(UNIXPRIV) REFRESH                                           
                                                                                
/* show results .................................................... */         
  RLIST   FACILITY ZWES.IS           ALL                                        
  RLIST   UNIXPRIV SUPERUSER.FILESYS ALL                                        
                                                                                
/* DEFINE ZSS SERVER PERMISIONS .................................... */         
                                                                                
/* permit ZSS to create a user's security environment                */         
/* ATTENTION: Defining the BPX.DAEMON or BPX.SERVER profile makes    */         
/*            z/OS UNIX switch to z/OS UNIX level security, which is */         
/*            more secure, but it can impact operation of existing   */         
/*            applications. Test this thoroughly before activating   */         
/*            it on a production system.                             */         
  RLIST   FACILITY BPX.DAEMON ALL                                               
  RDEFINE FACILITY BPX.DAEMON UACC(NONE)                                        
  PERMIT BPX.DAEMON CLASS(FACILITY) ACCESS(UPDATE) ID(&ZSSUSER.)                
                                                                                
  RLIST   FACILITY BPX.SERVER ALL                                               
  RDEFINE FACILITY BPX.SERVER UACC(NONE)                                        
  PERMIT BPX.SERVER CLASS(FACILITY) ACCESS(UPDATE) ID(&ZSSUSER.)                
                                                                                
  SETROPTS RACLIST(FACILITY) REFRESH                                            
                                                                                
/* show results .................................................... */         
  RLIST   FACILITY BPX.DAEMON ALL                                               
  RLIST   FACILITY BPX.SERVER ALL                                               
                                                                                
/* ................................................................. */         
/* only the last RC is returned, this comment ensures it is a 0      */         
$$                                                                              
//*                                                                             
//*********************************************************************         
//*                                                                             
//* ACF2 ONLY, customize to meet your system requirements                       
//*                                                                             
//ACF2     DD DATA,DLM=$$,SYMBOLS=JCLONLY                                       
                                                                                
/* DEFINE ADMINISTRATORS ........................................... */         
                                                                                
/* group for administrators                                          */         
/*TODO ACF2 group for administrators                                 */         
                                                                                
/* DEFINE STARTED TASK ............................................. */         
                                                                                
/** uncomment to use SUPERUSER.FILESYS, see JCL comments             */         
/** group for started tasks                                          */         
/*TODO ACF2 group for started tasks                                  */         
                                                                                
/* userid for ZOWE, main server                                      */         
  INSERT &ZOWEUSER. GROUP(&STCGROUP.) SET PROFILE(USER) +                       
   DIV(OMVS) INSERT &ZOWEUSER. UID(&ZOWEUSER.)                                  
                                                                                
/* userid for ZSS, cross memory server                               */         
  INSERT &ZSSUSER. GROUP(&STCGROUP.) SET PROFILE(USER) +                        
   DIV(OMVS) INSERT &ZSSUSER. UID(&ZSSUSER.)                                    
                                                                                
/* userid for ZSS auxilary cross memory server                       */         
  INSERT &AUXUSER. GROUP(&STCGROUP.) SET PROFILE(USER) +                        
   DIV(OMVS) INSERT &AUXUSER. UID(&AUXUSER.)                                    
                                                                                
/*operator command F ACF2,REBUILD(USR),CLASS(P)                      */         
/*operator command F ACF2,OMVS                                       */         
                                                                                
/* started task for ZOWE, main server                                */         
  SET CONTROL(GSO)                                                              
  INSERT STC.&ZOWESTC.**** LOGONID(&ZOWEUSER.) GROUP(&STCGROUP.) +              
   STCID(&ZOWESTC.****)                                                         
                                                                                
/* started task for ZSS, cross memory server                         */         
  SET CONTROL(GSO)                                                              
  INSERT STC.&ZSSSTC.**** LOGONID(&ZSSUSER.) GROUP(&STCGROUP.) +                
   STCID(&ZSSSTC.****)                                                          
                                                                                
/* started task for ZSS auxilary cross memory server                 */         
  SET CONTROL(GSO)                                                              
  INSERT STC.&AUXSTC.**** LOGONID(&AUXUSER.) GROUP(&STCGROUP.) +                
   STCID(&AUXSTC.****)                                                          
                                                                                
/*operator command F ACF2,REFRESH(STC)                               */         
                                                                                
/* DEFINE ZOWE SERVER PERMISIONS ................................... */         
                                                                                
/* permit Zowe main server to use ZSS, cross memory server           */         
/*TODO ACF2 permit Zowe server READ to FACILITY ZWES.IS              */         
                                                                                
/** uncomment to use SUPERUSER.FILESYS, see JCL comments             */         
/** permit Zowe main server to write persistent data                 */         
/*TODO ACF2 permit Zowe server CONTROL to UNIXPRIV SUPERUSER.FILESYS */         
                                                                                
/* DEFINE ZSS SERVER PERMISIONS .................................... */         
                                                                                
/* permit ZSS to create a user's security environment                */         
/* ATTENTION: Defining the BPX.DAEMON or BPX.SERVER profile makes    */         
/*            z/OS UNIX switch to z/OS UNIX level security, which is */         
/*            more secure, but it can impact operation of existing   */         
/*            applications. Test this thoroughly before activating   */         
/*            it on a production system.                             */         
                                                                                
/*TODO ACF2 permit zss UPDATE to FACILITY BPX.DAEMON & BPX.SERVER    */         
                                                                                
/* ................................................................. */         
/* only the last RC is returned, this comment ensures it is a 0      */         
$$                                                                              
//*                                                                             
//*********************************************************************         
//*                                                                             
//* Top Secret ONLY, customize to meet your system requirements                 
//*                                                                             
//TSS      DD DATA,DLM=$$,SYMBOLS=JCLONLY                                       
                                                                                
/* DEFINE ADMINISTRATORS ........................................... */         
                                                                                
/* required updates:                                                 */         
/* - change "admin_grp_dpt" to the department owning the STC group   */         
                                                                                
/* optional updates:                                                 */         
/* - update 108 in "GID(108)" to a GID for the administrator group   */         
                                                                                
/* group for administrators                                          */         
  TSS LIST(&ADMINGRP.) SEGMENT(OMVS)                                            
  TSS CREATE(&ADMINGRP.) TYPE(GROUP) +                                          
   NAME('ZOWE ADMINISTRATORS') +                                                
   DEPT(admin_grp_dept)                                                         
  TSS ADD(&ADMINGRP.) GID(108)                                                  
                                                                                
                                                                                
/* DEFINE STARTED TASK ............................................. */         
                                                                                
/* required updates:                                                 */         
/* - change "stc_grp_dpt" to the department owning the STC group     */         
/* - change "usr_dpt" to the department owning the Zowe STC user IDs */         
/* - change "fac_owning_acid" to the acid that owns IBMFAC           */         
                                                                                
/* optional updates:                                                 */         
/* - update 109 in "GID(109)" to a GID for the STC group             */         
/* - update 110 in "UID(110)" to a UID for the Zowe STC user ID      */         
/* - update 111 in "UID(111)" to a UID for the ZSS STC user ID       */         
/* - update 112 in "UID(112)" to a UID for the ZSS AUX STC user ID   */         
                                                                                
/** uncomment to use SUPERUSER.FILESYS, see JCL comments             */         
/** group for started tasks                                          */         
/* TSS LIST(&STCGROUP.) SEGMENT(OMVS)                                */         
/* TSS CREATE(&STCGROUP.) TYPE(GROUP) +                              */         
/*  NAME('STC GROUP WITH OMVS SEGEMENT') +                           */         
/*  DEPT(stc_grp_dept)                                               */         
/* TSS ADD(&STCGROUP.) GID(109)                                      */         
                                                                                
/* userid for ZOWE, main server                                      */         
  TSS LIST(&ZOWEUSER.) SEGMENT(OMVS)                                            
  TSS CREATE(&ZOWEUSER.) TYPE(USER) PASS(NOPW,0) NAME('ZOWE') +                 
   DEPT(usr_dept)                                                               
  TSS ADD(&ZOWEUSER.) GROUP(&STCGROUP.) DFLTGRP(&STCGROUP.) +                   
   HOME(/tmp) OMVSPGM(/bin/sh) UID(110)                                         
                                                                                
/* userid for ZSS, cross memory server                               */         
  TSS LIST(&ZSSUSER.) SEGMENT(OMVS)                                             
  TSS CREATE(&ZSSUSER.) TYPE(USER) PASS(NOPW,0) NAME('ZOWE ZSS') +              
   DEPT(usr_dept)                                                               
  TSS ADD(&ZSSUSER.) GROUP(&STCGROUP.) DFLTGRP(&STCGROUP.) +                    
   HOME(/tmp) OMVSPGM(/bin/sh) UID(111)                                         
                                                                                
/* userid for ZSS auxilary cross memory server                       */         
  TSS LIST(&AUXUSER.) SEGMENT(OMVS)                                             
  TSS CREATE(&AUXUSER.) TYPE(USER) PASS(NOPW,0) NAME('ZOWE ZSS AUX') +          
   DEPT(usr_dept)                                                               
  TSS ADD(&AUXUSER.) GROUP(&STCGROUP.) DFLTGRP(&STCGROUP.) +                    
   HOME(/tmp) OMVSPGM(/bin/sh) UID(112)                                         
                                                                                
/* started task for ZOWE, main server                                */         
  TSS LIST(STC) PROCNAME(&ZOWESTC.) PREFIX                                      
  TSS ADD(STC) PROCNAME(&ZOWESTC.) ACID(&ZOWEUSER.)                             
  TSS ADD(&ZOWEUSER.) FAC(STC)                                                  
                                                                                
/* started task for ZSS, cross memory server                         */         
  TSS LIST(STC) PROCNAME(&ZSSSTC.) PREFIX                                       
  TSS ADD(STC) PROCNAME(&ZSSSTC.) ACID(&ZSSUSER.)                               
  TSS ADD(&ZSSUSER.) FAC(STC)                                                   
                                                                                
/* started task for ZSS auxilary cross memory server                 */         
  TSS LIST(STC) PROCNAME(&AUXSTC.) PREFIX                                       
  TSS ADD(STC) PROCNAME(&AUXSTC.) ACID(&AUXUSER.)                               
  TSS ADD(&AUXUSER.) FAC(STC)                                                   
                                                                                
/* DEFINE ZOWE SERVER PERMISIONS ................................... */         
                                                                                
/* required updates:                                                 */         
/* - change "fac_owning_acid" to the acid that owns IBMFAC           */         
                                                                                
/* permit Zowe main server to use ZSS, cross memory server           */         
  TSS ADD(fac_owning_acid) IBMFAC(ZWES.IS)                                      
  TSS WHOHAS IBMFAC(ZWES.IS)                                                    
  TSS PERMIT(&ZOWEUSER.) IBMFAC(ZWES.IS) ACCESS(READ)                           
                                                                                
/** uncomment to use SUPERUSER.FILESYS, see JCL comments             */         
/** permit Zowe main server to write persistent data                 */         
/*TODO TSS permit Zowe server CONTROL to UNIXPRIV SUPERUSER.FILESYS  */         
                                                                                
/* DEFINE ZSS SERVER PERMISIONS .................................... */         
                                                                                
/* required updates:                                                 */         
/* - change "fac_owning_acid" to the acid that owns IBMFAC           */         
                                                                                
/* permit ZSS to create a user's security environment                */         
/* ATTENTION: Defining the BPX.DAEMON or BPX.SERVER profile makes    */         
/*            z/OS UNIX switch to z/OS UNIX level security, which is */         
/*            more secure, but it can impact operation of existing   */         
/*            applications. Test this thoroughly before activating   */         
/*            it on a production system.                             */         
  TSS ADD(fac_owning_acid) IBMFAC(BPX.)                                         
  TSS WHOHAS IBMFAC(BPX.DAEMON)                                                 
  TSS PER(&ZSSUSER.) IBMFAC(BPX.DAEMON) ACC(UPDATE)                             
  TSS WHOHAS IBMFAC(BPX.SERVER)                                                 
  TSS PER(&ZSSUSER.) IBMFAC(BPX.SERVER) ACC(UPDATE)                             
                                                                                
/* ................................................................. */         
/* only the last RC is returned, this comment ensures it is a 0      */         
$$                                                                              
//*                                                                             
                                                                                
