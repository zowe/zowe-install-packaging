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
 * Count how many tracks are used by data set in DD SYSUT1.
 * Track count is written to DD SYSPRINT, prefixed by optional <info>.
 *
 *
 * >>--RXTRACKS--+--------+------------------------------------------><
 *               +--info--+
 *
 * Sample JCL:
 * //TRACKS   EXEC PGM=IKJEFT01,COND=(4,LT),
 * //            PARM='%RXTRACKS &PTF'
 * //SYSEXEC  DD DISP=SHR,DSN=&TOOL
 * //SYSTSPRT DD SYSOUT=*
 * //SYSTSIN  DD DUMMY
 * //SYSUT1   DD DISP=SHR,DSN=&$SYSMOD
 * //SYSPRINT DD SYSOUT=*
 *
 * EXECIO  documentation in "TSO/E REXX Reference (SA22-7790)"
 * listdsi documentation in "TSO/E REXX Reference (SA22-7790)"
 */
/* user variables ...................................................*/

/* system variables .................................................*/

/* system code ......................................................*/
parse arg Info
say ''                  /* ensure our first 'say' is on its own line */

/* get allocation data of DD SYSUT1 */
cRC=listdsi("SYSUT1 FILE")
if cRC > 4 then do
  say '>> ERROR: LISTDSI SYSUT1 RC' cRC 'RSN' SYSREASON
  say '>> ERROR:' SYSMSGLVL2
  exit 8                                            /* LEAVE PROGRAM */
end    /* */

/* retrieve used allocation, in tracks */
if wordpos(SYSDSSMS,'SEQ PDS') > 0
then select
  when SYSUNITS == 'TRACK'    then Tracks=SYSUSED
  when SYSUNITS == 'CYLINDER' then Tracks=SYSUSED*SYSTRKSCYL
  otherwise
    say '>> ERROR: allocation unit' SYSUNITS 'is not supported'
    exit 8                                          /* LEAVE PROGRAM */
  end    /* select */
else do
  say '>> ERROR: data set type' SYSDSSMS 'is not supported'
  exit 8                                            /* LEAVE PROGRAM */
end    /* */

say '> DD SYSUT1' right(Tracks,9) 'tracks in' Info
push right(Tracks,9) Info        /* right 9 allows for 100G-1 tracks */
"EXECIO 1 DISKW SYSPRINT (FINI"
if rc = 1 then rc=0                        /* record length mismatch */

exit rc                                             /* LEAVE PROGRAM */

