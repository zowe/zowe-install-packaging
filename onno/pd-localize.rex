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
 *% Localize a master file by removing/inserting text blocks at given
 *% locations.
 *%
 *% Arguments:
 *% -Debug       (optional) enable debug messages
 *% INsert=file  (optional) file holding text blocks to insert
 *%              DD INSERT used if not provided
 *% KEy=key      (optional) keyword to identify text blocks to remove
 *% MAster=file  master file to update
 *%              DD MASTER used if not provided
 *% OUtput=file  file to which updated master is written
 *%              DD OUTPUT used if not provided
 *%              specify '--' to update 'master' itself
 *% REmove=file  (optional) file to which removed text is written
 *%              DD REMOVE used if not provided
 *%
 *% Return code:
 *% 0: success
 *% 4: warning issued
 *% 8: processing error
 *% 12: input or exec error
 */
/*
 * Expected markers, with ??? a unique, single-word, keyword that is
 * consistent for one set of data blocks:
 * - marker indicating where specific data should be added:
 *   .*only-???-mark
 * - marker indicating start of specific data block:
 *   .*only-???-start
 * - marker indicating end of specific data block:
 *   .*only-???-stop
 */
/* user variables ...................................................*/
ddTemp='$$TEMP$$'                            /* name of temporary DD */
ddMaster='MASTER'                                /* name of input DD */
ddInsert='INSERT'                     /* name of DD with data to add */
ddRemove='REMOVE'                /* name of DD to store removed data */
ddOutput='OUTPUT'                /* name of DD to store updated file */
Mode='755'     /* z/OS UNIX access permission bits for writing files */

/* system variables .................................................*/
cRC=0                                              /* assume success */
Debug=0                                  /* assume not in Debug mode */
fMaster=''                             /* assume no input to process */
fInsert=''                                  /* assume no data to add */
fRemove=''                               /* assume no data to remove */
fOutput=''                              /* assume no output specfied */
Key=''                 /* assume no need to replace data with marker */
Master.0=0                                                /* no data */
Insert.0=0                                                /* no data */

/* system code ......................................................*/
parse source . . ExecName . . . . ExecEnv .         /* get exec info */
ExecName=substr(ExecName,lastpos('/',ExecName)+1)  /* $(basename $0) */

/* get startup arguments */
parse arg Args                          /* get all startup arguments */

do while Args <> ''
  parse var Args Action Args                   /* cut first argument */
  parse var Action xKey '=' xValue /* split in key & value if needed */
  upper xKey                                   /* make key uppercase */
  if Debug then say '. (args)' Action

  select
  when abbrev('-DEBUG',xKey,2)  then Debug=1  /* TRUE */
  when abbrev('INSERT',xKey,2)  then fInsert=xValue
  when abbrev('KEY',xKey,2)     then Key=xValue
  when abbrev('MASTER',xKey,2)  then fMaster=xValue
  when abbrev('OUTPUT',xKey,2)  then fOutput=xValue
  when abbrev('REMOVE',xKey,2)  then fRemove=xValue
  otherwise
    call _displayUsage
    say '** ERROR' ExecName 'invalid startup argument "'Action'"'
    cRC=12                 /* do not exit yet, show all errors first */
  end    /* select */
end    /* while Args */

if debug then do; say ''; parse arg Args; say '>' ExecName Args; end

/* in-place update requested ? */
if fOutput == '--'
then do
  if Debug then say '. in-place update enabled'
  fOutput=fMaster
  ddOutput=ddMaster
end    /* */

/* use DD if present and no startup argument specified */
if (fInsert == '') then if _ddExist(ddInsert) then fInsert='*'
if (fMaster == '') then if _ddExist(ddMaster) then fMaster='*'
if (fOutput == '') then if _ddExist(ddOutput) then fOutput='*'
if (fRemove == '') then if _ddExist(ddRemove) then fRemove='*'

call _report 'master',fMaster,ddMaster
call _report 'output',fOutput,ddOutput
call _report 'insert',fInsert,ddInsert
call _report 'remove',fRemove,ddRemove

/* validate startup arguments */
if fMaster == ''
then do
  call _displayUsage
  say '** ERROR' ExecName 'MASTER= or DD' ddMaster 'is required'
  cRC=12
end    /* */

if fOutput == ''
then do
  call _displayUsage
  say '** ERROR' ExecName 'OUTPUT= or DD' ddOutput 'is required'
  cRC=12
end    /* */

if cRC > 4 then exit 12                             /* LEAVE PROGRAM */

/* enable z/OS UNIX REXX syscall environment */
/* docu in "Using REXX and z/OS UNIX System Services (SA23-2283)" */
xRC=syscalls('ON')
if xRC > 4
then do               /* unable to establish the SYSCALL environment */
  Text.='undocumented error code'
  Text.7='the process was dubbed, but the SYSCALL environment' ,
         'was not established'
  Text.8='the process could not be dubbed'
  say '** ERROR' ExecName 'unable to establish the SYSCALL environment'
  say 'RC='xRC Text.xRC
  say ' '
  exit 12                                           /* LEAVE PROGRAM */
end    /* */

/* . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . */

/* read input */
Stem='Master.'
if (cRC <= 4)
then if \_readFile(fMaster,ddMaster)
  then cRC=max(cRC,8)

Stem='Insert.'
if (cRC <= 4) & (fInsert \= '')
then if \_readFile(fInsert,ddInsert)
  then cRC=max(cRC,8)

/* process input */
if (cRC <= 4) then cRC=max(cRC,_process(Key))

/* write results */
if (cRC <= 4) & (fRemove \= '')
then do
  Stem='Remove.'
  cRC=max(cRC,_writeFile(fRemove,ddRemove))
end    /* */

/* write 'Output' last to ensure 'Remove' is not lost on in-place
   update with failed 'Remove' write */
if (cRC <= 4)
then do
  Stem='Output.'
  cRC=max(cRC,_writeFile(fOutput,ddOutput))
end    /* */

/* . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . */

if ExecEnv <> 'OMVS' then call syscalls 'OFF'           /* ignore RC */
if debug then say '<' ExecName cRC
exit cRC                                            /* LEAVE PROGRAM */

/*---------------------------------------------------------------------
 * --- display script usage information
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
 * --- Convert boolean value to text
 * Returns FALSE or TRUE
 * Args:
 *  1: 0 or 1
 */
_boolean: /* NO PROCEDURE */
return word('FALSE TRUE',arg(1)+1)    /* _boolean */

/*---------------------------------------------------------------------
 * --- Report where data to be processed is obtained / will go to
 * Returns nothing
 * Args:
 *  _Name: name of data we're processing
 *  _File: file name / data set name, or '*'
 *  _DD  : DD name
 *
 * do NOT call from a routine that has values for
 * _Name _File _DD
 */
_report: /* NO PROCEDURE */
parse arg _Name,_File,_DD
if _File == '*'
  then say _Name': DD' _DD
  else say _Name':' _File
return    /* _report */

/*---------------------------------------------------------------------
 * --- Execute z/OS UNIX syscall command with basic error handling
 * Returns boolean indicating success (1) or not (0)
 * Args:
 *  _Cmd    : syscall command to execute
 *  _Verbose: (optional) flag to show syscall error message
 *  _Exit   : (optional) exit on REXX error
 *
 * do NOT call from a routine that has values for
 * _Err. _RC _RetVal _ErrNo _ErrNoJr _Success _Cmd _Verbose _Exit
 *
 * docu in "Using REXX and z/OS UNIX System Services (SA23-2283)"
 */
_syscall: /* NO PROCEDURE */
parse arg _Cmd,_Verbose,_Exit
parse value _Verbose 1 with _Verbose .  /* default: report USS error */
parse value _Exit 1 with _Exit .      /* default: exit on REXX error */
_Success=1  /* TRUE */
_Err.0=0

if Debug then say '. (syscall)' _Cmd
address SYSCALL _Cmd
parse value rc retval errno errnojr with _RC _RetVal _ErrNo _ErrNoJr
if Debug then say '.           rc' _RC 'retval' _RetVal ,
                'errno' _ErrNo 'errnojr' _ErrNoJr

if _RC < 0
then do                                                /* REXX error */
  _Success=0  /* FALSE */
  say ''
  say '** ERROR' ExecName 'syscall command failed:' _Cmd
  select
  when (_RC < -20) & (_RC > -30) then
    say 'argument' abs(_RC)-20 'is in error'
  when _RC = -20 then
    say 'unknown SYSCALL command or improper number of arguments'
  when _RC = -3 then
    say 'not in SYSCALL environment'
  otherwise
    say 'error flagged by REXX language processor'
  end    /* select */
  if _Exit then exit 12                             /* LEAVE PROGRAM */
end    /* REXX error */
else if _RetVal == -1
  then do                                              /* UNIX error */
    _Success=0  /* FALSE */
    if _Verbose
    then do                                      /* report the error */
      say ''
      say '** ERROR' ExecName 'syscall command failed:' _Cmd
      say 'ErrNo('_ErrNo') ErrNoJr('_ErrNoJr')'
      address SYSCALL 'strerror' _ErrNo _ErrNoJr '_Err.'
      do T=1 to _Err.0 ; say _Err.T ; end
    end    /* report */
  end    /* UNIX error */
/*else nop */ /* Note: a few cmds use retval <> -1 to indicate error */

/* set syscall output vars back to value after command execution */
drop rc retval errno errnojr /* ensure that the name is used in parse*/
parse value _RC _RetVal _ErrNo _ErrNoJr with rc retval errno errnojr
return _Success    /* _syscall */

/*---------------------------------------------------------------------
 * --- Write data to z/OS Unix file, MVS data set, or DD
 * Returns return code
 * Args:
 *  File: file name / data set name to write to, or '*' for DD
 *  DD: DD name to write to
 */
_writeFile: PROCEDURE EXPOSE ExecName Debug Mode ddTemp (Stem)
parse arg File,DD
if Debug then say '> _writeFile' File','DD
if Debug then say '. writing' value(Stem'0') 'lines'

if pos('/',File) > 0                             /* z/OS UNIX file ? */
then cRC=word('8 0',_syscall('writefile' File Mode Stem)+1)
else if File == '*'                                          /* DD ? */
  then cRC=_ddWrite(DD,'*','(FINI STEM' Stem)
  else do                    /* write data set, assumes we're in TSO */
    "ALLOCATE FILE("ddTemp") REUSE SHR DATASET('"File"')"
    xRC=rc
    if xRC == 0
    then do
      cRC=_ddWrite(ddTemp,'*','(FINI STEM' Stem)
      "FREE FILE("ddTemp")"
    end    /* alloc success */
    else do
      say '** ERROR' ExecName 'allocate DD' ddTemp 'for' File,
        'failed, RC' xRC
      cRC=8
    end    /* alloc failure */
  end    /* data set */

if Debug then say '< _writeFile' cRC
return cRC    /* _writeFile */

/*---------------------------------------------------------------------
 * --- Read data from z/OS Unix file, MVS data set, or DD
 * Returns boolean indicating success (1) or not (0)
 * Updates stem referenced by variable Stem
 * Args:
 *  File: file name / data set name to read, or '*' for DD
 *  DD: DD name to read
 *
 * EXECIO documentation in "TSO/E REXX Reference (SA22-7790)"
 */
_readFile: PROCEDURE EXPOSE ExecName Debug ddTemp (Stem)
parse arg File,DD
if Debug then say '> _readFile' File','DD

if pos('/',File) > 0                             /* z/OS UNIX file ? */
then do
  Success=_syscall('readfile' File Stem)
  if Debug then say '. readfile' Stem'0='value(Stem'0')
end
else if File == '*'                                          /* DD ? */
  then Success=_ddRead(DD)
  else do                     /* read data set, assumes we're in TSO */
    "ALLOCATE FILE("ddTemp") REUSE SHR DATASET('"File"')"
    xRC=rc
    if xRC == 0
    then do
      Success=_ddRead(ddTemp)
      "FREE FILE("ddTemp")"
    end    /* alloc success */
    else do
      say '** ERROR' ExecName 'allocate DD' ddTemp 'for' File,
        'failed, RC' xRC
      Success=0  /* FALSE */
    end    /* alloc failure */
  end    /* data set */

if Debug then say '< _readFile' _boolean(Success)
return Success    /* _readFile */

/*---------------------------------------------------------------------
 * --- Write to DD
 * Returns return code
 * Args:
 *  DD   : DD name to write to
 *  Count: number of lines to write, can be '*'
 *  Parms: EXECIO parameters
 *
 * EXECIO documentation in "TSO/E REXX Reference (SA22-7790)"
 */
_ddWrite: PROCEDURE EXPOSE ExecName Debug (Stem)
parse arg DD,Count,Parms
if Debug then say '> _ddWrite' DD','Count','Parms
cRC=0                                              /* assume success */

"EXECIO" Count "DISKW" DD Parms
select
when rc == 0 then nop
when rc == 1 then do
  say '** WARNING data in DD' DD 'was truncated.'
  cRC=max(cRC,4)
end    /* */
otherwise
  say '** ERROR' ExecName 'writing DD' DD
  if rc == 20
    then say 'RC='rc 'Severe error.'
    else say 'RC='rc 'Undocumented error code.'
  cRC=max(cRC,8)
end    /* select */

if Debug then say '< _ddWrite' cRC
return cRC    /* _ddWrite */

/*---------------------------------------------------------------------
 * --- Read DD and place content in stem Line.
 * Returns boolean indicating success (1) or not (0)
 * Updates stem referenced by variable Stem
 * Args:
 *  DD: DD name to read
 *
 * EXECIO documentation in "TSO/E REXX Reference (SA22-7790)"
 */
_ddRead: PROCEDURE EXPOSE ExecName Debug (Stem)
parse upper arg DD
if Debug then say '> _ddRead' DD
cRC=0                                              /* assume success */
call value Stem'0',0                                      /* no data */

"EXECIO * DISKR" DD "(FINIS STEM" Stem
if Debug then say '. execio' Stem'0='value(Stem'0')
/* /                                                         * trace *
Lines=value(Stem'0')
do T=0 to Lines
  say '.' Stem||T'='value(Stem||T)
end
/ *                                                          * trace */

Success=(rc == 0)
if \Success
then do
  Text.='Undocumented error code.'
  Text.4='An empty data set was found in the data set concatenation.'
  Text.20='Severe error.'
  say '** ERROR' ExecName 'reading DD' DD
  say 'RC='rc Text.rc
end    /* */

if Debug then say '< _ddRead' _boolean(Success)
return Success    /* _ddRead */

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
_ddExist: PROCEDURE EXPOSE ExecName Debug ExecEnv
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
    say '** ERROR' ExecName 'LISTALC RC' rc 'while searching for DD' DD
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
 * --- create Output. based on Master. with Insert. inserted and
 *     removed data stored in Remove.
 * Returns return code
 * Updates stems Output. and Remove.
 * Args:
 *  RemoveKey: key that marks data to be removed
 *
 * Note: remove part can also be done with awk when in USS
 * 1. save data to be removed
 * awk '/^.*only-???-start$/{f=1} f{print}  /^.*only-???-stop$/{f=0}'
 *   file > replaceFile
 * 2. replace data with marker
 * awk 'BEGIN{f=1} /^.*only-???-start$/{f=0} f{print}
 *   /^.*only-???-stop$/{f=1;print ".*only-???-mark"}' file > newfile
 *
 */
_process: PROCEDURE EXPOSE ExecName Debug Master. Insert. Remove. Output.
parse arg RemoveKey
if Debug then say '> _process' RemoveKey
cRC=0                                              /* assume success */
Output.0=0                                                   /* no data */
Remove.0=0                                                /* no data */

if RemoveKey == ''
  then RemoveKey='no data removal'
  else say 'removing key' RemoveKey

/* get insert key from line 1 of data to be inserted */
/* Insert.1 is ".*only-???-start" */
if Insert.0 == 0
then InsertKey='no input substitution'
else do
  parse var Insert.1 . '-' InsertKey '-' .
  say 'inserting key' InsertKey
end    /* */

/* loop through master document */
if Debug then say '. processing' Master.0 'lines'
N=0; I=1; R=0
do T=1 to Master.0
  Master.T=strip(Master.T,'T')               /* strip traling blanks */
  if Master.T == '' then Master.T=' '               /* no null lines */

  if left(Master.T,7) == '.*only-'     /* special tag on this line ? */
  then do
    if Debug then say '.' T Master.T

    /* Master.T is ".*only-???-start" or ".*only-???-mark" */
    parse var Master.T . '-' Key '-' Mode

    if wordpos(Mode,'start stop mark') == 0
    then do
      say '** ERROR' ExecName 'invalid tag at line' T 'of master file'
      say Master.T
      cRC=max(cRC,8)
      leave                                          /* LEAVE LOOP T */
    end    /* */

/* . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . */

    /* keep tags we're not processing */
    if  ((Mode == 'start') & (Key \= RemoveKey)) ,
      | ((Mode == 'mark') & (Key \= InsertKey)),
      | (Mode == 'stop')
    then do
      if Debug then say '. skipping this tag'
      N=N+1; Output.N=Master.T
      iterate                                         /* NEXT LOOP T */
    end    /* */

/* . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . */

    /* replace data with mark-tag */
    /* do remove first to support replacing existing text in 1 pass */
    if (Mode == 'start') & (Key == RemoveKey)
    then do
      if Debug then say '. remove from line' T

      /* set aside lines until end tag (including start/stop tags) */
      do while (Master.T \= '.*only-'Key'-stop') & (T <= Master.0)
        R=R+1; Remove.R=Master.T
        T=T+1
      end    /* while remove */

      if (Master.T == '.*only-'Key'-stop') & (T <= Master.0)
      then do; R=R+1; Remove.R=Master.T; end          /* add stop tag */
      else do
        say '** ERROR' ExecName,
          'no closing ".*only-'Key'-stop" tag in master file'
        cRC=max(cRC,8)
        leave                                        /* LEAVE LOOP T */
      end    /* */

      if Debug then say '. removed until line' T', total' R 'lines'

      N=N+1; Output.N='.*only-'Key'-mark'         /* add placeholder */
      Mode='mark'     /* allow for replacing existing text in 1 pass */
    end    /* remove block */

/* . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . */

    /* replace mark-tag with data */
    if (Mode == 'mark') & (Key == InsertKey)
    then do
      if Debug then say '. insert from line' I', at line' N

      if I > Insert.0
      then do
        say '** ERROR' ExecName,
          'unable to add data at line' T 'of master file'
        say Master.T
        cRC=max(cRC,8)
        leave                                        /* LEAVE LOOP T */
      end    /* */

      /* add lines until end tag (including start/stop tags) */
      do while (Insert.I \= '.*only-'Key'-stop') & (I <= Insert.0)
        N=N+1; Output.N=Insert.I
        I=I+1
      end    /* while insert */

      if (Insert.I == '.*only-'Key'-stop') & (I <= Insert.0)
      then do; N=N+1; Output.N=Insert.I; I=I+1; end  /* add stop tag */
      else do
        say '** ERROR' ExecName,
          'no closing ".*only-'Key'-stop" tag in insert file'
        cRC=max(cRC,8)
        leave                                        /* LEAVE LOOP T */
      end    /* */

      if Debug then say '. inserted until line' I-1
    end    /* insert block */

/* . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . */

  end    /* tag found */
  else do
    N=N+1; Output.N=Master.T
    if Debug & (N // 500 = 0) then say '. @ line' N
  end    /* */
end    /* loop T */

if I <= Insert.0
then do
  say '** WARNING not all lines inserted, stopped at insert line' I
  cRC=max(cRC,4)
end    /* */

Output.0=N
Remove.0=R
say 'new file has' N 'lines, original has' Master.0 'lines'
say I-1 'lines inserted,' R 'lines removed'

if Debug then say '< _process' cRC
return cRC    /* _process */

