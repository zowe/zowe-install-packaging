//Z7REJECT JOB 
//*                                                                   
//* This program and the accompanying materials are made available    
//* under the terms of the Eclipse Public License v2.0 which          
//* accompanies this distribution, and is available at                
//* https://www.eclipse.org/legal/epl-v20.html                        
//*                                                                   
//* SPDX-License-Identifier: EPL-2.0                                  
//*                                                                   
//* Copyright Contributors to the Zowe Project. 2019, 2020            
//*                                                                   
//********************************************************************
//*                                                                   
//* This JCL will remove a SYSMOD (PTF, APAR, USERMOD) from SMPPTS.   
//*                                                                   
//*                                                                   
//* CAUTION: This is neither a JCL procedure nor a complete job.      
//* Before using this job step, you will have to make the following   
//* modifications:                                                    
//*                                                                   
//* 1) Add the job parameters to meet your system requirements.       
//*                                                                   
//* 2) Change #csihlq to the high level qualifier for the global zone 
//*    of the CSI.                                                    
//*                                                                   
//* 3) Change #sysmod to the name of the SYSMOD to be received.       
//*                                                                   
//* Note(s):                                                          
//*                                                                   
//* 1. This job should complete with a return code 0.                 
//*                                                     
//* 2. REJECT acts on co-requisite SYSMODs simultaneously, 
//*    so only one of them is specified.                   
//*                                                     
//********************************************************************
//*                                                                   
//REJECT   EXEC PGM=GIMSMP,REGION=0M
//SMPCSI   DD DISP=OLD,DSN=#globalcsi
//SMPCNTL  DD *                                                       
   SET BOUNDARY(GLOBAL) . 
   LIST SYSMODS .                                            
   REJECT BYPASS(APPLYCHECK)                                          
          SELECT(                                                     
   #sysmod1
   ) .   
//*                                                                   