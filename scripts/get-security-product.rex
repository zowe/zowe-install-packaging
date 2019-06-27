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
 *% Determine the primary security product.
 *%
 *% Arguments:
 *% -d  (optional) enable debug messages
 *%
 *% Return code:
 *% 0:  primary security product is RACF
 *% 1:  primary security product is ACF2
 *% 2:  primary security product is Top Secret
 *% 8:  primary security product is unknown
 */
/* user variables ...................................................*/

/* system variables .................................................*/
cRC=0                                                 /* assume RACF */
Debug=0                                  /* assume not in debug mode */

/* system code ......................................................*/
parse source . . ExecName . . . . ExecEnv .         /* get exec info */
ExecName=substr(ExecName,lastpos('/',ExecName)+1)  /* $(basename $0) */

/* get startup arguments */
if word(arg(1),1) = '-d' then Debug=1                /* debug mode ? */

if Debug then do; say ''; say '>' ExecName; end

/* get RCVTID value (eye catcher of RCVT control block) */
FLCCVT=_ptr(,16,4)                            /* PSA, MVS Data Areas */
CVTRAC=_ptr(FLCCVT,992,4)                     /* CVT, MVS Data Areas */
RCVTID=_ptr(CVTRAC,0,4)                     /* RCVT, RACF Data Areas */

select
when RCVTID='RCVT' then do; cRC=0; if Debug then say 'RACF'; end
when RCVTID='ACF2' then do; cRC=1; if Debug then say 'ACF2'; end
when RCVTID='RTSS' then do; cRC=2; if Debug then say 'Top Secret'; end
otherwise
  cRC=8; if Debug then say 'unknown ('RCVTID')'
end    /* select */

if Debug then say '<' ExecName cRC
exit cRC                                            /* LEAVE PROGRAM */

/*-------------------------------------------------------------------*/
/* --- Get arg_3 bytes from addr string arg_1 + decimal offset arg_2
 * Returns requested storage content as string
 * Args:
 *  1: base storage address as string, can be a null string
 *  2: offset to base address, in decimal
 *  3: number of bytes to return, in decimal
 */
_ptr: /* NO PROCEDURE */
return storage(d2x(c2d(arg(1))+arg(2)),arg(3))    /* _ptr */
