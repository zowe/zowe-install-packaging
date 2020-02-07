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
 * Count how many lines are in DD SYSUT1.
 * Line count is written to DD SYSPRINT, prefixed by optional <info>.
 *
 *
 * >>--RXLINES--+--------+-------------------------------------------><
 *              +--info--+
 *
 * Sample JCL:
 * //LINES    EXEC PGM=IKJEFT01,COND=(4,LT),
 * //            PARM='%RXLINES &MBR'
 * //SYSEXEC  DD DISP=SHR,DSN=&TOOL
 * //SYSTSPRT DD SYSOUT=*
 * //SYSTSIN  DD DUMMY
 * //SYSUT1   DD DISP=SHR,DSN=&$PART
 * //SYSPRINT DD SYSOUT=*
 */
/* user variables ...................................................*/
BufSize=15000                                  /* size of I/O buffer */

/* system variables .................................................*/
cRC=0                                              /* assume success */
EOF=0  /* FALSE */                                /* not end-of-file */
Lines=0                                              /* 0 lines read */

/* system code ......................................................*/
parse arg Info

do until EOF
  "EXECIO" BufSize "DISKR SYSUT1 (STEM Buffer."
  if rc == 2 then do; rc=0; EOF=1; end                 /* RC 2 = EOF */
  cRC=max(cRC,rc)
  if cRC >= 4 then leave                               /* LEAVE LOOP */
/*say '> DD SYSUT1' Buffer.0 'lines'*/
  Lines=Lines+Buffer.0
end    /* do until EOF */
"EXECIO 0 DISKR SYSUT1 (FINI"

if cRC == 0
then do
  say '> DD SYSUT1' right(Lines,7) 'lines in' Info
  push right(Lines,7) Info /* right 7 as PTF has max 5,000,000 lines */
  "EXECIO 1 DISKW SYSPRINT (FINI"
  if rc = 1 then rc=0                      /* record length mismatch */
  cRC=max(cRC,rc)
end    /* */
exit cRC
