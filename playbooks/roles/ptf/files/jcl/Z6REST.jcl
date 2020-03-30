//Z6REST   JOB 
//*                                                                    
//* This program and the accompanying materials are made available     
//* under the terms of the Eclipse Public License v2.0 which           
//* accompanies this distribution, and is available at                 
//* https://www.eclipse.org/legal/epl-v20.html                         
//*                                                                    
//* SPDX-License-Identifier: EPL-2.0                                   
//*                                                                    
//* Copyright Contributors to the Zowe Project. 2019, 2020             
                                                                  
//******************************************************************** 
//*                                                                    
//* This JCL will RESTORE a service SYSMOD (PTF, APAR, USERMOD).       
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
//* 3) Change #tzone to your CSI target zone name.                     
//*                                                                    
//* 4) Change #sysmod to the name of the SYSMOD to be restored.        
//*                                                                    
//* Note(s):                                                           
//*                                                                    
//* 1. The RESTORE process will replace the affected elements in the   
//*    target libraries with the version from the distribution         
//*    libraries. This implies that you cannot RESTORE a SYSMOD once it
//*    has been accepted. This also implies that you must RESTORE all  
//*    SYSMODS that have been applied since the last accepted SYSMOD.  
//*                                                                    
//* 2. This job should complete with a return code 0.                  
//*                                                                    
//******************************************************************** 
//*                                                                    
//RESTORE  EXEC PGM=GIMSMP,REGION=0M
//SMPCSI   DD DISP=OLD,DSN=#globalcsi
//SMPCNTL  DD *                                                        
   SET BOUNDARY(#tzone) .         
   LIST SYSMODS .                                     
   RESTORE SELECT(                                                     
   #sysmod1
   #sysmod2
   ) .                                                                 
//*                                                                    