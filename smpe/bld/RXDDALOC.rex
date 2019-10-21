/* REXX */
/*
 * This program and the accompanying materials are made available
 * under the terms of the Eclipse Public License v2.0 which
 * accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project. 2019, 2019
 */
/*
 * Allocates DD ddname and writes a blank to it.
 *
 *
 * >>--RXDDALOC--ddname----------------------------------------------><
 *
 *
 * Sample JCL:
 * //DDALLOC  EXEC PGM=IKJEFT01,COND=(4,LT),
 * //            PARM='%RXDDALOC &MVS'
 * //SYSEXEC  DD DISP=SHR,DSN=&TOOL
 * //SYSTSPRT DD SYSOUT=*
 * //SYSTSIN  DD DUMMY
 */
/* user variables ...................................................*/

/* system variables .................................................*/

/* system code ......................................................*/
arg DD .                                           /* auto uppercase */
say 'allocating DD' DD 'as marker where we are in the job'
say 'the DD shows up at the end of the DD list in SDSF'

if DD == '' | length(DD) > 8 then exit 8            /* LEAVE PROGRAM */

"ALLOC FI("DD") REUSE SYSOUT"               /* ignore possible error */
push " "
"EXECIO 1 DISKW" DD "(FINIS"
cRC=rc
if cRC == 1 then cRC=0                       /* line length mismatch */
"FREE FI("DD")"                             /* ignore possible error */
exit cRC                                            /* LEAVE PROGRAM */
