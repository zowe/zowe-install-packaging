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
//* This JCL procedure is used to start the main ZOWE server
//*
//* Invocation arguments:
//* HOME - Directory where Zowe is installed
//*        sample default: /usr/lpp/zowe
//* CFG  - Absolute path to the zowe.yaml configuration file
//*        sample default: /etc/zowe.yaml
//* PRM  - Provide additional startup arguments
//*        sample default: ''
//*        -d - Debug mode
//*
//* Note(s):
//*
//* 1. This procedure contains case sensitive path statements.
//*
//* 2. The combined length of the HOME, CFG, and PRM values must be 
//*    less than 73 characters.
//*
//*********************************************************************
//*
//* ZOWE MAIN SERVER
//*
//ZOWESVR  PROC RGN=0M,
// HOME='/usr/lpp/zowe',
//  CFG='/etc/zowe.yaml',
//  PRM=''
//*      123456789012345678901234567890123456789012345678901234567890
//*               1         2         3         4         5         6
//*
//ZOWESVR EXEC PGM=BPXBATSL,REGION=&RGN,               TIME=NOLIMIT,
// PARM='PGM &HOME/scripts/zowe-run.sh -c &CFG &PRM'
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
