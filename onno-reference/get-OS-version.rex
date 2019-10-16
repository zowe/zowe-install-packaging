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
 *% Determine the version of the operating system (sent to stdout).
 *% Note: debug adds lines starting with > or <.
 *%
 *% Arguments:
 *% -d  (optional) enable debug messages
 *%
 *% Return code:
 *% 0: success
 */
/* user variables ...................................................*/

/* system variables .................................................*/
Debug=0                                  /* assume not in debug mode */

/* system code ......................................................*/
parse source . . ExecName . . . . ExecEnv .         /* get exec info */
ExecName=substr(ExecName,lastpos('/',ExecName)+1)  /* $(basename $0) */

/* get startup arguments */
if word(arg(1),1) = '-d' then Debug=1                /* debug mode ? */

if Debug then do; say ''; say '>' ExecName; end

/* get VRM values */
FLCCVT=_ptr(,16,4)                            /* PSA, MVS Data Areas */
CVTECVT=_ptr(FLCCVT,140,4)                    /* CVT, MVS Data Areas */
ECVTPVER=_ptr(CVTECVT,512,2)                 /* ECVT, MVS Data Areas */
ECVTPREL=_ptr(CVTECVT,514,2)                 /* ECVT, MVS Data Areas */
ECVTPMOD=_ptr(CVTECVT,516,2)                 /* ECVT, MVS Data Areas */
/* Note: mvsvar('SYSOPSYS') gets its data from the same fields */

say ECVTPVER+0'.'ECVTPREL+0'.'ECVTPMOD+0        /* +0 to auto-format */

if Debug then say '<' ExecName '0'
exit 0                                              /* LEAVE PROGRAM */

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
