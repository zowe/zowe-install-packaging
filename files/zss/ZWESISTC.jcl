//ZWEZSS    PROC NAME='ZWESIS_STD',MEM=00,RGN=0M
//********************************************************************/
//* This program and the accompanying materials are made available   */
//* under the terms of the Eclipse Public License v2.0 which         */
//* accompanies this distribution, and is available at               */
//* https://www.eclipse.org/legal/epl-v20.html                       */
//*                                                                  */
//* SPDX-License-Identifier: EPL-2.0                                 */
//*                                                                  */
//* 5698-ZWE Copyright Contributors to the Zowe Project. 2018, 2019  */
//********************************************************************/
//*                                                                  */
//* Zowe Open Source Project                                         */
//* Sample STC JCL for the Zowe ZSS Cross-Memory Server              */
//*                                                                  */
//* 1. Run-time parameters                                           */
//*                                                                  */
//*   COLD  - Cold start                                             */
//*           RESET SERVER STATE.                                    */
//*           DO NOT USE WITHOUT CONSULTING WITH SUPPORT.            */
//*                                                                  */
//*           EXAMPLE: PARM='COLD'                                   */
//*   DEBUG - Debug mode                                             */
//*           EXAMPLE: PARM='DEBUG'                                  */
//*   NAME  - Name of this server                                    */
//*           ZWESIS_STD is the default name, the max length is 16.  */
//*           example: NAME='ZWESIS_02'                              */
//*   MEM   - Suffix of the ZWESIPxx member                          */
//*           00 is the default value.                               */
//*           example: MEM=02                                        */
//*                                                                  */
//* 2. STEPLIB data set name                                         */
//*                                                                  */
//* Verify and/or change the name of the STEPLIB data set            */
//*                                                                  */
//* The started task MUST use a STEPLIB DD statement to declare      */
//* the ZSS Cross-Memory Server load library name. This is required  */
//* so that the appropriate version of the software is loaded        */
//* correctly. Do NOT add the load library data set to the system    */
//* LNKLST or LPALST concatenations.                                 */
//*                                                                  */
//* 3. PARMLIB DD                                                    */
//*                                                                  */
//* Verify and/or change the name of the PARMLIB data set            */
//*                                                                  */
//* By default, the server will read its parameters from the         */
//* ZWESIPxx member in the PARMLIB DD statement. If you want to use  */
//* your system defined parmlib, comment out the PARMLIB DD.         */
//*                                                                  */
//********************************************************************/
//ZWESIS01 EXEC PGM=ZWESIS01,REGION=&RGN,
//            PARM='NAME=&NAME,MEM=&MEM'
//STEPLIB  DD DISP=SHR,DSN=ZWE.SZWEAUTH
//PARMLIB  DD DISP=SHR,DSN=ZWE.SZSESAMP
//SYSPRINT DD SYSOUT=*
//*
