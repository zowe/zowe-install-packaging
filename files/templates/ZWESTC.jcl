//********************************************************************
//* This program and the accompanying materials are made available   *
//* under the terms of the Eclipse Public License v2.0 which         *
//* accompanies this distribution, and is available at               *
//* https://www.eclipse.org/legal/epl-v20.html                       *
//*                                                                  *
//* SPDX-License-Identifier: EPL-2.0                                 *
//*                                                                  *
//* Copyright IBM Corporation 2018, 2019                             *
//********************************************************************
//*                                                                  *
//* ZOWE SERVER PROCEDURE                                            *
//*                                                                  *
//* This is a procedure to start the Node servers, API Mediation     *
//* and explorera                                                    *
//*                                                                  *
//* Invoke this procedure, specifying the root path where the        *
//* ZOWE server is installed on your system.                         *
//*                                                                  *
//*   S ZOWESVR,HOME='/zowe/install/path'                            *
//*                                                                  *
//********************************************************************
//ZOWESVR   PROC RGN=0M,
// HOME='/usr/lpp/zowe/v1'
//*-------------------------------------------------------------------
//* HOME - The path where the server was installed.
//*---------------------------------------------------------
//* Start the node server
//*---------------------------------------------------------
//ZOWESVR EXEC PGM=BPXBATSL,REGION=&RGN,TIME=NOLIMIT,
//            PARM='PGM /bin/sh &HOME/scripts/internal/run-zowe.sh'
//STDOUT   DD SYSOUT=*
//STDERR   DD SYSOUT=*
//*STDENV   DD PATH='/etc/zowe/zowesvr.stdenv',
//*            PATHOPTS=ORDONLY
//*-------------------------------------------------------------------
//* Optional logging parameters that can be configured if required
//*-------------------------------------------------------------------
//*STDOUT   DD PATH='/tmp/zowe.std.out',
//*            PATHOPTS=(OWRONLY,OCREAT,OTRUNC),
//*            PATHMODE=SIRWXU
//*STDERR   DD PATH='/tmp/zowe.std.err',
//*            PATHOPTS=(OWRONLY,OCREAT,OTRUNC),
//*            PATHMODE=SIRWXU
