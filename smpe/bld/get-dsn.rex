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
 *% Get a list of data set names that match a filter (sent to stdout).
 *% Note: debug adds lines starting with > or <.
 *%
 *% Arguments:
 *% -d    (optional) enable debug messages
 *% mask  dsn mask, wildcards (%, *, **) allowed
 *%
 *% Return code:
 *% 0: data set(s) match filter
 *% 1: no data set matches filter
 *% 8: error
 *%
 *% User must be authorized to use this utility:
 *% SYS1.LINKLIB(IGGCSI00) catalog search interface
 */
/* user variables ...................................................*/

/* system variables .................................................*/
cRC=0                                              /* assume success */
Debug=0                                  /* assume not in debug mode */

/* system code ......................................................*/
parse source . . ExecName . . . . ExecEnv .         /* get exec info */
ExecName=substr(ExecName,lastpos('/',ExecName)+1)  /* $(basename $0) */

/* get startup arguments */
if word(arg(1),1) <> '-d'                         /* no debug mode ? */
then parse arg Args                     /* get all startup arguments */
else do
  Debug=1
  parse arg . Args /* do not include the first (-d) startup argument */
end    /* */
/* process in two steps to have all startup args in 1 variable; Args */
parse var Args Dsn Trash              /* split in multiple variables */

if Debug then do; say ''; say '>' ExecName Args; end

/* validate startup arguments */
if Dsn == ''
then do
  call _displayUsage
  say '** ERROR' ExecName 'dsn is required'
  cRC=8
end    /* */

if Trash \= ''
then do
  call _displayUsage
  say '** ERROR' ExecName 'invalid startup argument' Trash
  cRC=8
end    /* */

/* . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . */

/* get DSN list */
if cRC == 0 then cRC=_readCatalog(Dsn,'A')

if Debug then say '<' ExecName cRC
exit cRC                                            /* LEAVE PROGRAM */

/*---------------------------------------------------------------------
 * --- Display script usage information
 * Returns nothing
 */
_displayUsage: PROCEDURE EXPOSE ExecName
say ''
say ' 'ExecName
T=0
Found=0
do while T < sourceline()                  /* scan REXX line by line */
  T=T+1; Line=sourceline(T)
  if left(Line,3) == ' *%'               /* usage information line ? */
  then do
    Found=1        /* stop when this usage information block is done */
    say substr(strip(Line,'T'),4)  /* strip header & trailing blanks */
  end    /* */
  else if Found then leave                             /* LEAVE LOOP */
end    /* while T */
say ''
return    /* _displayUsage */

/*---------------------------------------------------------------------
 * --- Displays data set names that match the filter
 * Retuns return code
 * Args:
 *  Filter: limit catalog search to this mask (*, ** and % allowed)
 *  Type  : (optional) up to 16 letters indicating which data set
 *          types are acceptable (see dType variable for list)
 *          default allows all types
 *  Vsam  : (optional) 'Y' to show DATA & INDEX of VSAM cluster
 *          default only shows cluster name
 *
 * User must be authorized to use this utility:
 * SYS1.LINKLIB(IGGCSI00) catalog search interface
 *
 * Documentation in "DFSMS: Managing Catalogs (SC23-6853)"
 */
_readCatalog: PROCEDURE EXPOSE ExecName Debug
parse upper arg Filter,Type,Vsam       /* get arguments in uppercase */
if Type == '' then Type=' '         /* default: Type=' ' (allow all) */
if Vsam == '' then Vsam=' '      /* default: Vsam=' ' (only cluster) */

if Debug then say '> _readCatalog' Filter','Type','Vsam

/* initialize invocation variables ..................................*/
Resume  ='Y'                                     /* prepare to loop  */
PrevName=''                                      /* no previous name */
cRC     =1                                       /* assume no match  */

/* initialize the CSI parm list .....................................*/
/* 1) reason area */
MODRSNRC=left(' ',4)                 /* clear module/return/reason   */
/* 2) selection critera fields */
CSIFILTK=left(Filter,44)             /* copy filter key into list    */
CSICATNM=left(' ',44)                /* clear catalog name           */
CSIRESNM=left(' ',44)                /* clear resume name            */
CSIDTYPS=left(Type,16)               /* allow selected entry types   */
CSICLDI =left(Vsam,1)                /* indicate data and index      */
CSIRESUM=left(' ',1)                 /* clear resume flag            */
CSIS1CAT=left(' ',1)                 /* indicate search > 1 catalogs */
CSIRESRV=left(' ',1)                 /* clear reserve character      */
CSINUMEN='0000'X                     /* init number of fields        */
/*INUMEN='0001'X                      * init number of fields        */
/*IFLD1 =left('VOLSER',8)             * init field 1 for volsers     */
/* >>>> adjust CSIFIELD when CSINUMEN changes <<<< */

CSIOPTS =CSICLDI || CSIRESUM || CSIS1CAT || CSIRESRV
CSIFIELD=CSIFILTK || CSICATNM || CSIRESNM || CSIDTYPS || CSIOPTS ||,
         CSINUMEN /*|| CSIFLD1 */
/* 3) work area */
WORKLEN =x2d('0FA00')      /* work area size, max 1,048,575 (xFFFFF) */
DWORK   ='0000FA00'X || copies('00'X,WORKLEN-4)   /* first word=size */

/* main CSI loop ....................................................*/
do while Resume = 'Y'

/* issue link to "catalog generic filter interface" (CSI) */
  address LINKPGM 'IGGCSI00  MODRSNRC  CSIFIELD  DWORK'

  Resume =substr(CSIFIELD,150,1)    /* get resume flag for next loop */
  UsedLen=c2d(substr(DWORK,9,4))    /* get amount of work area used  */
  Offset =15                        /* starting position             */

/* process data returned in work area */
  do while Offset < UsedLen
/* 1) catalog entry */
    if substr(DWORK,Offset+1,1) = '0'
    then do
      cName=strip(substr(DWORK,Offset+2,44))         /* catalog name */
      nop
      Offset=Offset+50
    end    /* catalog entry */
/* 2) data set entry */
    dType=substr(DWORK,Offset+1,1)                  /* data set type */
    dName=strip(substr(DWORK,Offset+2,44))          /* data set name */

    select
      when dType = 'A' then dType='NONVSAM'
      when dType = 'C' then dType='CLUSTER'
      when dType = 'D' then dType='DATA'
      when dType = 'I' then dType='INDEX'
      when dType = 'G' then dType='AIX'
      when dType = 'R' then dType='PATH'
      when dType = 'B' then dType='GDG'
      when dType = 'H' then dType='GDS'
      when dType = 'X' then dType='ALIAS'
      when dType = 'U' then dType='UCAT'
      when dType = 'L' then dType='ATLLIB'
      when dType = 'W' then dType='ATLVOL'
      otherwise iterate   /* no entries in catalog, look at next one */
    end    /* select */

/* process requested CSI fields */
    Offset=Offset + 46
/*  dVolser=substr(DWORK,Offset+6,6) */          /* get first volser */
/*  dVolser.0=c2d(substr(DWORK,Offset+4,2))/6 */   /* get all volser */
/*  do T=1 to dVolser.0 ; dVolser.T=substr(DWORK,Offset+(6*T),6) ; en*/

/* do your stuff */
/* >>>>> */
    cRC=0                                      /* at least one match */
    say strip(dName)            /* strip leading and trailing blanks */
/* <<<<< */

/* get position of next entry */
    Offset=Offset+C2D(substr(DWORK,Offset,2))
  end    /* data set entry */

/* iterate when resume is necessary */
  if (Resume = 'Y') & (PrevName = dName)    /* if we tried this one  */
  then do                                   /* twice, we got to quit */
    say '** ERROR' ExecName dName 'cannot be processed with the work',
        'area provided, increase the work area size and retry'
    cRC=8
    leave                                              /* LEAVE LOOP */
  end    /* error */
  PrevName=dName                          /* save for next iteration */
end    /* do while */

if Debug then say '< _readCatalog' cRC
return cRC      /* _readCatalog */
