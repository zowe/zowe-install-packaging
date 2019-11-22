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
/* Unload a member to a sequential data set, using IEBCOPY for lmods
 * and OCOPY for the rest.
 * Expects that source is in DD SYSUT1 and target in DD SYSUT2.
 * For lmod:
 * - DD PDSE and PDS are also required for staging copies.
 * - DD PDSE must be allocated with LRECL=0
 * - If DD MCS is present and has data, it must hold the MCS data
 *   for the part to be copied.
 *   The data will be interpreted to locate aliases and determine
 *   whether the target loadlib is PDS or PDS/E (default).
 * - Aditional member names can be passed in as argument which are
 *   treated as alias. With this override, MCS defined aliases are
 *   ignored.
 *   Specify a period (.) to drop all alias processing.
 * For all other members:
 * - Binary OCOPY is used.
 *
 * >>--RXUNLOAD--+--------------------------+------------------------><
 *               +-member--+--+-------+--+--+
 *                         |  +-alias-+  |
 *                         |  +-<-,---+  |
 *                         +------.------+
 *
 * Return code:
 * 0:  completed successfully
 * 8:  input or processing error
 * 12: exec error
 *
 * User must be authorized to:
 * -SYS1.LINKLIB(IEBCOPY)
 * -SYS1.LINKLIB(OCOPY)
 *
 * Sample JCL:
 * //LMOD     EXEC PGM=IKJEFT01,COND=(4,LT),
 * //            PARM='%RXUNLOAD'
 * //SYSPROC  DD DISP=SHR,DSN=&TOOL
 * //SYSTSPRT DD SYSOUT=*
 * //SYSTSIN  DD DUMMY
 * //SYSUT1   DD DISP=SHR,DSN=&REL(&MVS)
 * //SYSUT2   DD DISP=(NEW,PASS),DSN=&UNLOAD,
 * //            DCB=(DSORG=PS,RECFM=FB,LRECL=6160),
 * //            SPACE=(&SIZE,RLSE),UNIT=SYSALLDA
 * //MCS      DD DISP=(SHR,PASS),DSN=&MCS
 * //PDSE     DD DISP=(NEW,PASS),UNIT=SYSALLDA,DSN=&COPY,
 * //            LIKE=&REL,SPACE=(&SIZE,RLSE),DSNTYPE=LIBRARY,LRECL=0
 * //PDS      DD DISP=(NEW,PASS),UNIT=SYSALLDA,LIKE=&COPY,
 * //            SPACE=(,(,,5)),DSNTYPE=PDS,LRECL=0  * LRECL 0 REQUIRED
 *
 * EXECIO  documentation in "TSO/E REXX Reference (SA22-7790)"
 * listdsi documentation in "TSO/E REXX Reference (SA22-7790)"
 * LISTALC documentation in "TSO/E Command Reference (SA22-7782)"
 */
/* user variables ...................................................*/
ddMCS='MCS'                           /* name of DD holding MCS data */
Debug=0                                  /* assume not in debug mode */

/* system variables .................................................*/

/* system code ......................................................*/
/* trace s */ /* trace r */
parse source . . ExecName . . . . ExecEnv .         /* get exec info */

say ''                  /* ensure our first 'say' is on its own line */

if (ExecEnv == 'OMVS')
then do
  say '>> ERROR:' ExecName 'not supported in OMVS'
  exit 8                                            /* LEAVE PROGRAM */
end    /* */

/* get list of data sets linked to DD SYSUT1 */
parse value _getDD('SYSUT1',0) with cRC In
if cRC > 0 then exit 8                              /* LEAVE PROGRAM */
if words(In) \== 1 then do
  say '>> ERROR: invalid SYSUT1 allocation "'In'"'
  exit 8                                            /* LEAVE PROGRAM */
end    /* */

/* get list of data sets linked to DD SYSUT2 */
parse value _getDD('SYSUT2',0) with cRC Out
if cRC > 0 then exit 8                              /* LEAVE PROGRAM */
if words(Out) \== 1 then do
  say '>> ERROR: invalid SYSUT2 allocation "'Out'"'
  exit 8                                            /* LEAVE PROGRAM */
end    /* */

/* get DCB data of DD SYSUT2 */
cRC=listdsi("SYSUT2 FILE")
if \(cRC <= 4 & left(SYSDSORG,2) == 'PS')
then do
  say '>> ERROR: SYSUT2 must be a sequential data set'
  say '>> ERROR: DSORG of SYSUT2 is' SYSDSORG
  say '>> ERROR: LISTDSI SYSUT2 RC' cRC 'RSN' SYSREASON
  say '>> ERROR:' SYSMSGLVL2
  exit 8                                            /* LEAVE PROGRAM */
end    /* */

/* get DCB data of DD SYSUT1, must be last listdsi() call */
cRC=listdsi("SYSUT1 FILE")
if cRC > 4 then do
  say '>> ERROR: LISTDSI SYSUT1 RC' cRC 'RSN' SYSREASON
  say '>> ERROR:' SYSMSGLVL2
  exit 8                                            /* LEAVE PROGRAM */
end    /* */

/* get member name from DD or startup arg (from MCS is done later) */
parse var In . '(' Mbr ')' .      /* get member name from DD, if any */
parse upper arg Member Alias    /* get name from startup arg, if any */
/* note, both Mbr & Member can be null strings */
if Mbr == Member then Member=''                        /* no doubles */
parse value Mbr Member with Mbr Member .  /* Member->Mbr if possible */
/* if Mbr  = '' & Member  = '' then Mbr=''     ; Member=''     */
/* if Mbr  = '' & Member \= '' then Mbr=Member ; Member=''     */
/* if Mbr \= '' & Member  = '' then Mbr=Mbr    ; Member=''     */
/* if Mbr \= '' & Member \= '' then Mbr=Mbr    ; Member=Member */
if Member \= ''                        /* Member still has a value ? */
then do
  say '>> ERROR: DD SYSUT1 specifies member' Mbr', but startup',
      'argument specifies' Member
  exit 8                                            /* LEAVE PROGRAM */
end    /* */
Alias=translate(Alias,' ',',')           /* comma -> blank separated */

/* get member name from MCS (also get PDS flag & do alias setup) */
select
when Alias == '' then do                     /* get aliases from MCS */
  parse value _mcs(ddMCS,Mbr) with PDS Mbr Alias
end
when Alias == '.' then do               /* skip all alias processing */
  parse value _mcs(ddMCS,Mbr) with PDS Mbr .
  Alias=''
end
otherwise                         /* get alias from startup argument */
  parse value _mcs(ddMCS,Mbr) with PDS Mbr .
end    /* select */

/* safety net, should never hit */
if Mbr == ''
then do
  say '>> ERROR: a member name is required (arg, SYSUT1 or MCS)'
  exit 8                                            /* LEAVE PROGRAM */
end    /* */

/* interpret DCB of SYSUT1 to decide which copy method to use */
if pos('U',SYSRECFM) == 0
  then cRC=_ocopy(In,Out,Mbr)                            /* non-lmod */
  else cRC=_iebcopy(In,Out,Mbr,Alias,PDS)             /* load module */
exit cRC                                            /* LEAVE PROGRAM */


/*---------------------------------------------------------------------
 * --- Copy member in SYSUT1 to SYSUT2 using OCOPY
 * Returns RC
 * Args:
 *  In : name of data set linked to DD SYSUT1
 *  Out: name of data set linked to DD SYSUT2
 *  Mbr: name of member to process
 *
 * OCOPY documentation in "UNIX System Services Command Reference
 *  (SA23-2280)"
 * ALLOC documentation in "TSO/E Command Reference (SA22-7782)"
 * FREE documentation in "TSO/E Command Reference (SA22-7782)"
 */
_ocopy: PROCEDURE EXPOSE Debug ExecEnv
parse arg In,Out,Mbr
if Debug then say '> _ocopy' In','Out','Mbr
Mode='BINARY'

/* is member part of SYSUT1 allocation ? */
parse var In DSN '(' Member .
if Member = ''
then do
  say '> reallocating SYSUT1 as DISP=SHR,DSN='DSN'('Mbr')'
  "FREE FI(SYSUT1)"
  "ALLOC FI(SYSUT1) REUSE SHR DSN('"DSN"("Mbr")')"
  if rc > 0
  then do
    /* error details already reported */
    say '>> ERROR: reallocating SYSUT1 ended with RC' rc
    return 8                                        /* LEAVE ROUTINE */
  end    /* */
end    /* realloc with member */

say '> from:' DSN Mbr
say '> to:  ' Out
say '> using' Mode 'OCOPY'

"OCOPY INDD(SYSUT1) OUTDD(SYSUT2)" Mode              /* SYS1.LINKLIB */
cRC=rc

if cRC \= 0
  then say '>> ERROR: OCOPY ended with RC' cRC

if Debug then say '< _ocopy' cRC
return cRC    /* _ocopy */


/*---------------------------------------------------------------------
 * --- Copy lmod with aliases in SYSUT1 to SYSUT2 using IEBCOPY
 * Returns RC
 * Args:
 *  In   : name of data set linked to DD SYSUT1
 *  Out  : name of data set linked to DD SYSUT2
 *  Mbr  : name of member to process
 *  Alias: '' or list of aliases to process
 *  PDS  : 1 (PDS) or 0 (PDS/E)
 *
 * IEBCOPY changes DCB upon unload, use only for LMODs
 *
 * IEBCOPY documentation in "DFSMSdfp Utilities (SC23-6864)"
 * ALLOC documentation in "TSO/E Command Reference (SA22-7782)"
 * FREE documentation in "TSO/E Command Reference (SA22-7782)"
 */
_iebcopy: PROCEDURE EXPOSE Debug ExecEnv
parse arg In,Out,Mbr,Alias,PDS
if Debug then say '> _iebcopy' In','Out','Mbr','Alias','PDS
cRC=0                                              /* assume success */

if \_ddExist('PDSE') | \_ddExist('PDS')
then do
  say '>> ERROR: DD PDSE and PDS must be allocated'
  cRC=max(cRC,8)
end    /* */

/* is member part of SYSUT1 allocation ? */
parse var In DSN '(' Member .
if Member \= ''
then do
  say '> reallocating SYSUT1 as DISP=SHR,DSN='DSN
  "FREE FI(SYSUT1)"
  "ALLOC FI(SYSUT1) REUSE SHR DSN('"DSN"')"
  if rc > 0
  then do
    /* error details already reported */
    say '>> ERROR: reallocating SYSUT1 ended with RC' rc
    cRC=max(cRC,8)
  end    /* */
end    /* realloc without member */

if cRC > 0
then do
  if Debug then say '< _iebcopy' cRC
  return cRC                                        /* LEAVE ROUTINE */
end    /* */

say '> from:' DSN Mbr Alias
say '> to:  ' Out
say '> using' word('PDS/E PDS',1+PDS) 'IEBCOPY'

do while queued() > 0; pull .; end                    /* clear stack */

/* step 1 - copy member & aliases to PDSE to force LRECL=0 */

/* create IEBCOPY control data to copy member & alias(es) */
queue " COPY OUTDD=PDSE,INDD=SYSUT1"
/* do not use COPYGRP, verify alias presence by explicit select */
queue " SELECT MEMBER="Mbr
do while Alias \== ''
  parse var Alias Mbr Alias
  queue " SELECT MEMBER="Mbr
end    /* while Alias */

/* copy SYSUT1 -> PDSE */
cRC=__iebcopy('SYSUT1','PDSE')

if (ExecEnv \= 'OMVS') & (cRC = 0)
then do
  /* check LRECL to be sure it's 0 (must be after __iebcopy()) */
  cRC=listdsi("PDSE FILE")
  if cRC > 4 then do
    say '>> ERROR: LISTDSI PDSE RC' cRC 'RSN' SYSREASON
    say '>> ERROR:' SYSMSGLVL2
    cRC=8
  end    /* */
  else if SYSLRECL \= 0
    then do
      say '>> ERROR: PDSE has LRECL' SYSLRECL
      cRC=8
    end    /* */
end    /* not in OMVS & copy successful */

if cRC > 0
then do
  if Debug then say '< _iebcopy' cRC
  return cRC                                        /* LEAVE ROUTINE */
end    /* */

/* step 2 - copy PDSE to PDS if required (for LPA) */

if \PDS
then inDD='PDSE'  /* used in step 3 */
else do
  inDD='PDS'  /* used in step 3 */

  /* create IEBCOPY control data to copy everything in PDSE */
  queue " COPY OUTDD=PDS,INDD=PDSE"                  /* control data */
  cRC=__iebcopy('PDSE','PDS')

  if (ExecEnv \= 'OMVS') & (cRC = 0)
  then do
    /* check LRECL to be sure it's 0 (must be after __iebcopy()) */
    cRC=listdsi("PDS FILE")
    if cRC > 4 then do
      say '>> ERROR: LISTDSI PDS RC' cRC 'RSN' SYSREASON
      say '>> ERROR:' SYSMSGLVL2
      cRC=8
    end    /* */
    else if SYSLRECL \= 0
      then do
        say '>> ERROR: PDS has LRECL' SYSLRECL
        cRC=8
      end    /* */
  end    /* not in OMVS & copy successful */

  if cRC > 0
  then do
    if Debug then say '< _iebcopy' cRC
    return cRC                                      /* LEAVE ROUTINE */
  end    /* */
end    /* convert to PDS */

/* step 3 - copy staged member(s) to sequential data set */

/* create IEBCOPY control data to copy everything in "inDD" */
queue " COPY OUTDD=SYSUT2,INDD="inDD
cRC=__iebcopy(inDD,'SYSUT2')

if Debug then say '< _iebcopy' cRC
return cRC    /* _iebcopy */


/*---------------------------------------------------------------------
 * --- Invoke IEBCOPY with error handling
 * Returns RC
 * Args:
 *  ddMCS: name of DD holding MCS data
 *
 * Assumes caller placed SYSIN on stack
 *
 * IEBCOPY documentation in "DFSMSdfp Utilities (SC23-6864)"
 * ALLOC documentation in "TSO/E Command Reference (SA22-7782)"
 * FREE documentation in "TSO/E Command Reference (SA22-7782)"
 * EXECIO documentation in "TSO/E REXX Reference (SA22-7790)"
 * CALL documentation in "TSO/E REXX Reference (SA22-7790)"
 */
/*-------------------------------------------------------------------*/
__iebcopy: PROCEDURE EXPOSE Debug ExecEnv
parse upper arg ddFrom,ddTo
if Debug then say '> __iebcopy' ddFrom','ddTo

/* allocate IEBCOPY data sets */            /* ignore possible error */
"ALLOC FI(SYSIN)    REUSE DEL DSO(PS) REC(F B) LR(80)  SP(1,1) TRACK"
"ALLOC FI(SYSPRINT) REUSE DEL DSO(PS) REC(F B) LR(121) SP(5,5) TRACK"

/* caller must stage SYSIN data on stack */
"EXECIO * DISKW SYSIN (FINI"                /* ignore possible error */
          /* caller must do allocations to match provided SYSIN data */
"CALL *(IEBCOPY)"                                    /* SYS1.LINKLIB */
cRC=rc
drop List.
"EXECIO * DISKR SYSPRINT (FINI STEM List."  /* ignore possible error */

if cRC \= 0
then do
  say '>> ERROR: IEBCOPY from' ddFrom 'to' ddTo 'ended with RC' cRC
  do T=1 to List.0; say List.T; end
  cRC=8
end    /* iebcopy error */

"FREE FI(SYSIN SYSPRINT)"                   /* ignore possible error */

if Debug then say '< __iebcopy' cRC
return cRC    /* __iebcopy */


/*---------------------------------------------------------------------
 * --- Read the definition for this part from DD ddMCS
 * Returns string holding part definition
 *         mcs_definition_in_1_line
 * Args:
 *  ddMCS: name of DD holding MCS data
 *
 * Assumes MCS has been filtered down to just 1 ++ definition
 *
 * EXECIO documentation in "TSO/E REXX Reference (SA22-7790)"
 */
_readMCS: PROCEDURE EXPOSE Debug ExecEnv
parse upper arg ddMCS
if Debug then say '> _readMCS' ddMCS
MCS.=''                 /* initialize all stem fields to null string */

if \_ddExist(ddMCS)
then nop                         /* no error if ddMCS does not exist */
else do
  "EXECIO * DISKR" ddMCS "(FINI STEM MCS."
  cRC=rc
  if cRC >= 4
  then say '>> ERROR: EXECIO DISKR' ddMCS 'ended with RC' cRC
  else do T=2 to MCS.0                                /* make 1 line */
    MCS.1=space(MCS.1 MCS.T)
  end    /* loop T */
end    /* ddMCS exists */

if Debug then say '< _readMCS' MCS.1
return MCS.1    /* _readMCS */


/*---------------------------------------------------------------------
 * --- Examine MCS to determine if lmod must be processed as
 *     PDS member, get member name and possible aliases
 * Returns boolean indicating PDS is required (1) or not (0), string
 *         holding member name and possible member aliases
 *         1_(PDS)_or_0_(PDS/E) member_name member_aliases
 * Args:
 *  ddMCS: name of DD holding MCS data
 *  Mbr  : '' or member name
 */
_mcs: PROCEDURE EXPOSE Debug ExecEnv
parse arg ddMCS,Mbr
if Debug then say '> _mcs' ddMCS','Mbr
PDS=0  /* FALSE */                                   /* assume PDS/E */
Alias=''

MCS=translate(_readMCS(ddMCS))   /* uppercase MCS data for this part */
/* sample output:
 * ++PROGRAM(ZWESAUX )  SYSLIB(SZWEAUTH) DISTLIB(AZWEAUTH) RELFILE(3) .
 */

/* get ++ type & part name */
parse var MCS . '++' Type . '(' Part . ')' .

/* safety net */
if (Mbr \== '') & (Mbr \== Part) & (Part \== '')
then do
  say '>> ERROR: member' Mbr 'is selected but MCS data is for' Part
  say '>>' MCS
  exit 8                                            /* LEAVE PROGRAM */
end    /* */

if Type == 'PROGRAM'
then do
  /* is there an ALIAS definition ? */
  parse var MCS found 'ALIAS' . '(' Alias ')' .
  /* if ALIAS is defined then "found" holds at least '++PROGRAM' */
  if found == ''
    then Alias=''             /* wipe possible data as it is invalid */
    else Alias=translate(alias,' ',',')  /* comma -> blank delimited */

  /* is this for LPA (requires PDS) ? */
  parse var MCS found 'SYSLIB' . '(' target ')' .
  if (found \== '') & (right(strip(target),3) == 'LPA')
    then PDS=1  /* TRUE */
end    /* ++PROGRAM */

if Debug then say '< _mcs' _boolean(PDS) Part Alias
return PDS Part Alias    /* _mcs */


/*---------------------------------------------------------------------
 * --- Convert boolean value to text
 * Returns FALSE or TRUE
 * Args:
 *  1: 0 or 1
 */
_boolean: /* NO PROCEDURE */
return word('FALSE TRUE',arg(1)+1)    /* _boolean */


/*---------------------------------------------------------------------
 * --- Test whether DD exists or not
 * Returns boolean indicating DD exists (1) or not (0)
 * Args:
 *  DD: DD name to test
 *
 * listdsi is picky and can throw RC16 RSNxx for valid allocations,
 *  using LISTALC as backup method
 * listdsi documentation in "TSO/E REXX Reference (SA22-7790)"
 * LISTALC documentation in "TSO/E Command Reference (SA22-7782)"
 */
_ddExist: PROCEDURE EXPOSE Debug ExecEnv
parse upper arg DD
if Debug then say '> _ddExist' DD
Exist=0  /* FALSE */                             /* assume not found */

if (ExecEnv \= 'OMVS') & \Exist
then do
  cRC=listdsi(DD 'FILE')
  if Debug then say '. listdsi' DD 'RC' cRC 'RSN' SYSREASON
           /* sysout/sysin/dummy *//* not catlg'd */ /* tmp data set */
  Exist=((cRC <=4) | (SYSREASON =3) | (SYSREASON =5) | (SYSREASON =27))
  if Debug & \Exist then say '.' SYSMSGLVL2
end    /* not in OMVS & not found */

if (ExecEnv \= 'OMVS') & \Exist
then do
  if Debug then say '. parsing LISTALC output'

  call outtrap Line.
  "LISTALC STATUS SYSNAMES"
  call outtrap 'OFF'
  if rc \= 0
  then do
    say '** ERROR LISTALC RC' rc 'while searching for DD' DD
    do T=1 to Line.0 ; say Line.T ; end
  end    /* rc <> 0 */
  else do
    /* sample LISTALC output:
     * //TEST     EXEC PGM=IKJEFT01,REGION=0M,COND=(4,LT),
     * //            PARM='LISTALC STATUS SYSNAMES'
     * //PASS     DD DISP=(NEW,PASS),SPACE=(CYL,(1,1)),UNIT=SYSALLDA,
     * //            DCB=(DSORG=PS,RECFM=FB,LRECL=80)
     * //CONCAT   DD DISP=SHR,DSN=IBMUSER.EXEC
     * //         DD DISP=SHR,DSN=IBMUSER.NEW.EXEC
     * //SYSTSPRT DD SYSOUT=*
     * //SYSTSIN  DD DUMMY
     * //CONCAT2  DD DUMMY
     * //         DD DISP=SHR,DSN=IBMUSER.JCL
     * //         DD DUMMY
     * //USS      DD PATH='/u/ibmuser'
     * //CONCAT3  DD DISP=(NEW,PASS),SPACE=(CYL,(1,1)),UNIT=SYSALLDA,
     * //            DCB=(DSORG=PS,RECFM=FB,LRECL=80)
     * //         DD DISP=SHR,DSN=IBMUSER.EXEC
     * //         DD DISP=SHR,DSN=IBMUSER.NEW.EXEC
     *
     * --DDNAME---DISP--
     * SYS17039.T182438.RA000.LISTA.R0109101
     *   PASS     PASS
     * IBMUSER.EXEC
     *   CONCAT   KEEP
     * IBMUSER.NEW.EXEC
     *            KEEP
     * IBMUSER.LISTA.JOB20098.D0000101.?
     *   SYSTSPRT DELETE
     * NULLFILE  SYSTSIN
     * NULLFILE  CONCAT2
     * IBMUSER.JCL
     *            KEEP
     * NULLFILE
     * /u/ibmuser
     *   USS      KEEP,KEEP
     * SYS17039.T182438.RA000.LISTA.R0109102
     *   CONCAT3  PASS
     * IBMUSER.EXEC
     *            KEEP
     * IBMUSER.NEW.EXEC
     *            KEEP
     */

    /*do T=0 to Line.0; say '. LISTALC' T Line.T; end*/     /* trace */
    do T=1 to Line.0
      parse var Line.T word1 word2 .
      if word2 == '' then iterate                     /* NEXT LOOP T */
      if word1 == 'NULLFILE' then word1=word2
      if DD == word1 then leave     /* found DD ? */ /* LEAVE LOOP T */
    end    /* loop T */

    Exist=(T <= Line.0)
  end    /* LISTALC rc 0 */
end    /* not in OMVS & not found */

if Debug then say '< _ddExist' _boolean(Exist)
return Exist    /* _ddExist */


/*---------------------------------------------------------------------
 * --- Get a list of allocations for a given DD
 * Returns RC & list of (concatenated) allocations
 *         rc alloc_1 alloc_2 ...
 *  RC 0: completed successfully
 *  RC 4: DD not found
 *  RC 8: error
 * Args:
 *  DD: DD name to test
 *
 * LISTALC documentation in "TSO/E Command Reference (SA22-7782)"
 */
_getDD: PROCEDURE EXPOSE Debug ExecEnv
parse arg findDD
if Debug then say '> _getDD' findDD
DDs.=''                 /* initialize all stem fields to null string */

if ExecEnv == 'OMVS'
then do
  say '>> ERROR: LISTALC not supported in OMVS'
  cRC=8
end    /* */
else do
  x=outtrap('Line.')
  "LISTALC STATUS"
  cRC=rc
  x=outtrap('OFF')
  if cRC <> 0
  then do
    say '>> ERROR: LISTALC RC' cRC
    do T=1 to Line.0 ; say '>> ERROR:' Line.T ; end
    cRC=8
  end    /* cRC <> 0 */
  else do
    /* sample LISTALC output:
     * //TEST     EXEC PGM=IKJEFT01,REGION=0M,COND=(4,LT),
     * //            PARM='LISTALC STATUS SYSNAMES'
     * //PASS     DD DISP=(NEW,PASS),SPACE=(CYL,(1,1)),UNIT=SYSALLDA,
     * //            DCB=(DSORG=PS,RECFM=FB,LRECL=80)
     * //CONCAT   DD DISP=SHR,DSN=IBMUSER.EXEC
     * //         DD DISP=SHR,DSN=IBMUSER.NEW.EXEC
     * //SYSTSPRT DD SYSOUT=*
     * //SYSTSIN  DD DUMMY
     * //CONCAT2  DD DUMMY
     * //         DD DISP=SHR,DSN=IBMUSER.JCL
     * //         DD DUMMY
     * //USS      DD PATH='/u/ibmuser'
     * //CONCAT3  DD DISP=(NEW,PASS),SPACE=(CYL,(1,1)),UNIT=SYSALLDA,
     * //            DCB=(DSORG=PS,RECFM=FB,LRECL=80)
     * //         DD DISP=SHR,DSN=IBMUSER.EXEC
     * //         DD DISP=SHR,DSN=IBMUSER.NEW.EXEC
     *
     * --DDNAME---DISP--
     * SYS17039.T182438.RA000.LISTA.R0109101
     *   PASS     PASS
     * IBMUSER.EXEC
     *   CONCAT   KEEP
     * IBMUSER.NEW.EXEC
     *            KEEP
     * IBMUSER.LISTA.JOB20098.D0000101.?
     *   SYSTSPRT DELETE
     * NULLFILE  SYSTSIN
     * NULLFILE  CONCAT2
     * IBMUSER.JCL
     *            KEEP
     * NULLFILE
     * /u/ibmuser
     *   USS      KEEP,KEEP
     * SYS17039.T182438.RA000.LISTA.R0109102
     *   CONCAT3  PASS
     * IBMUSER.EXEC
     *            KEEP
     * IBMUSER.NEW.EXEC
     *            KEEP
     */

    /*do T=1 to Line.0; say '. LISTALC' T Line.T; end*/     /* trace */
    DD=''; cRC=4
    do T=2 to Line.0
    /*say '.' Line.T*/                                      /* trace */
      select
      when left(Line.T,3) == '   ' then do /* add last DSN to last DD*/
        DDs.DD=DDs.DD DSN
      /*say '. ++' DD DSN*/                                 /* trace */
      end    /* */
      when left(Line.T,1) == ' ' then do   /* add last DSN to new DD */
        parse var Line.T DD .
        if DD==findDD then cRC=0
        DDs.!keys=DDs.!keys DD
        DDs.DD=DSN
      /*say '. +=' DD DSN*/                                 /* trace */
      end    /* */
      when left(Line.T,9) == 'NULLFILE ' then do /* new DD, NULLFILE */
        parse var Line.T . DD .
        if DD==findDD then cRC=0
        DDs.!keys=DDs.!keys DD
      /*say '. +-' DD*/                                     /* trace */
      end    /* */
      otherwise                                       /* DSN or path */
        DSN=strip(Line.T)
      end    /* select */
    /*say '. -> DD' DD 'New' New 'DSN' DSN*/                /* trace */
    end    /* loop T */

    if Debug
    then do
      Cnt=words(DDs.!keys)
      say '.' Cnt 'DDs:'DDs.!keys
      do T=1 to Cnt
        DD=word(DDs.!keys,T)
        say '. DD' left(DD,8) '('words(DDs.DD)')' DDs.DD
      end    /* loop T */
      if cRC == 0
        then say '. DD' findDD 'found'
        else say '. DD' findDD 'not found'
    end    /* debug */
  end    /* LISTALC successful */
end    /* not in OMVS */

if Debug then say '< _getDD' cRC DDs.findDD
return cRC DDs.findDD    /* _getDD */
