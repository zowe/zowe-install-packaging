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
 *% Determine how to distribute parts among PTFs (sent to stdout).
 *% Note: debug adds lines starting with >, . or <.
 *%
 *% Arguments:
 *% -d        (optional) enable debug messages
 *% file      file holding a sorted list of parts & line-counts
 *% header1   number of lines used by header of first PTF in set
 *% header2   number of lines used by header of overflow PTF(s) in set
 *% reserved  (optional) number of PTFs reserved for this set
 *%
 *% Return code:
 *% 0: completed successfully
 *% 8: input or processing error
 *% 12: exec error
 */
/* user variables ...................................................*/

/* system variables .................................................*/
cRC=0                                              /* assume success */
Debug=0                                  /* assume not in debug mode */
!Vars.=''                      /* init stem holding global variables */

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
if Debug then do; say ''; say '>' ExecName Args; end

/* split startup arguments in multiple vars */
parse var Args File !Vars.!Hdr1 !Vars.!Hdr2 !Vars.!Reserved Trash
parse value !Vars.!Reserved 1 with !Vars.!Reserved .   /* default: 1 */

/* validate startup arguments */
if File == ''
then do
  call _displayUsage
  say '** ERROR' ExecName 'file is required'
  cRC=8
end    /* */

if !Vars.!Hdr1 == ''
then do
  call _displayUsage
  say '** ERROR' ExecName 'header1 is required'
  cRC=8
end    /* */

if !Vars.!Hdr2 == ''
then do
  call _displayUsage
  say '** ERROR' ExecName 'header2 is required'
  cRC=8
end    /* */

/* TODO test Hdr1 & Hdr2 numeric */

if Trash \= ''
then do
  call _displayUsage
  say '** ERROR' ExecName 'invalid startup argument' Trash
  cRC=8
end    /* */

if cRC > 4 then exit 8                              /* LEAVE PROGRAM */

/* . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . */

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
  exit 8                                            /* LEAVE PROGRAM */
end    /* */

if _readFile(File)                          /* get size of each part */
  then call _distribute               /* determine part distribution */
  else cRC=8

if ExecEnv <> 'OMVS' then call syscalls 'OFF'           /* ignore RC */
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
 * --- Convert boolean value to text
 * Returns boolean
 * Args:
 *  1: 0 or 1
 */
_boolean: /* NO PROCEDURE */
return word('FALSE TRUE',arg(1)+1)    /* _boolean */

/*---------------------------------------------------------------------
 * --- Execute z/OS UNIX syscall command with basic error handling
 * Returns boolean indicating success (1) or not (0)
 * Args:
 *  @Cmd    : syscall command to execute
 *  @Verbose: (optional) flag to show syscall error message
 *  @Exit   : (optional) exit on REXX error
 *
 * do NOT call from a routine that has values for
 * @Err. @RC @RetVal @ErrNo @ErrNoJr @Success @Cmd @Verbose @Exit
 *
 * docu in "Using REXX and z/OS UNIX System Services (SA23-2283)"
 */
_syscall: /* NO PROCEDURE */
parse arg @Cmd,@Verbose,@Exit
parse value @Verbose 1 with @Verbose .  /* default: report USS error */
parse value @Exit 1 with @Exit .      /* default: exit on REXX error */
@Success=1  /* TRUE */
@Err.0=0

if Debug then say '. (syscall)' @Cmd
address SYSCALL @Cmd
parse value rc retval errno errnojr with @RC @RetVal @ErrNo @ErrNoJr
if Debug then say '.           rc' @RC 'retval' @RetVal ,
                'errno' @ErrNo 'errnojr' @ErrNoJr

if @RC < 0
then do                                                /* REXX error */
  @Success=0  /* FALSE */
  say ''
  say '** ERROR' ExecName 'syscall command failed:' @Cmd
  select
  when (@RC < -20) & (@RC > -30) then
    say 'argument' abs(@RC)-20 'is in error'
  when @RC = -20 then
    say 'unknown SYSCALL command or improper number of arguments'
  when @RC = -3 then
    say 'not in SYSCALL environment'
  otherwise
    say 'error flagged by REXX language processor'
  end    /* select */
  if @Exit then exit 8                              /* LEAVE PROGRAM */
end    /* REXX error */
else if @RetVal == -1
  then do                                              /* UNIX error */
    @Success=0  /* FALSE */
    if @Verbose
    then do                                      /* report the error */
      say ''
      say '** ERROR' ExecName 'syscall command failed:' @Cmd
      say 'ErrNo('@ErrNo') ErrNoJr('@ErrNoJr')'
      address SYSCALL 'strerror' @ErrNo @ErrNoJr '@Err.'
      do T=1 to @Err.0 ; say @Err.T ; end
    end    /* report */
  end    /* UNIX error */
/*else nop */ /* Note: a few cmds use retval <> -1 to indicate error */

/* set syscall output vars back to value after command execution */
drop rc retval errno errnojr /* ensure that the name is used in parse*/
parse value @RC @RetVal @ErrNo @ErrNoJr with rc retval errno errnojr
return @Success    /* _syscall */

/*---------------------------------------------------------------------
 * --- interpret line-count file
 * Returns boolean
 * Updates:
 *  !Vars.!Lines.*: list of line counts
 *  !Vars.!Parts.*: list of part names
 * Args:
 *  File: path of file to interpret
 */
_readFile: PROCEDURE EXPOSE ExecName Debug !Vars.
parse arg File
if Debug then say '> _readFile' File
Verbose=1  /* TRUE */                        /* syscall error report */

/* read file */
OK=_syscall('readfile' File '!File.',Verbose)           /* read file */
if OK & (!File.0 = 0)
then do
  OK=0  /* FALSE */
  say '** ERROR' ExecName File 'is an empty file'
end    /* */

/* interpret file */
if OK
then do
/*
 * sample !File. content
 * 1494165 ZWEPAX05
 *  933752 ZWEPAX06
 *       6 ZWESIPRG
 */
  !Vars.!Total=0                            /* init total line count */
  !Vars.!Lines.0=!File.0                   /* set number of elements */
  !Vars.!Parts.0=!File.0
  do T=1 to !File.0   /* place word 1 in !Lines and word 2 in !Parts */
    parse var !File.T !Vars.!Lines.T !Vars.!Parts.T .
    !Vars.!Total=!Vars.!Total + !Vars.!Lines.T
  end    /* loop T */
end    /* interpret file */

drop !File.
if OK & Debug then say '.' !Vars.!Parts.0' parts,' !Vars.!Total 'lines'
if Debug then say '< _readFile' _boolean(OK)
return OK    /* _readFile */

/*---------------------------------------------------------------------
 * --- determine absolute minimum number of required PTFs
 * Returns minimum number of PTFs required
 * IBM: max PTF size is 5,000,000 * 80 bytes (including SMP/E metadata)
 *      5mio lines requires 7,164 tracks
 * IBM: max 900 parts per PTF
 * Args: /
 */
_minCount: PROCEDURE EXPOSE ExecName Debug !Vars.
if Debug then say '> _minCount'

/* minimum number of lines is total for parts + first PTF header */
Total=!Vars.!Total + !Vars.!Hdr1
PTFs=1

do while Total > 5000000                   /* max 5mio lines per PTF */
  PTFs=PTFs+1
  /* subtract theoretical lines in prev PTF, add size new PTF header */
  Total=Total - 5000000 + !Vars.!Hdr2
end    /* while Total */

do while !Vars.!Parts.0 > (PTFs * 900)      /* max 900 parts per PTF */
  PTFs=PTFs+1
end    /* while parts */

/* caller expects to use !Vars.!Reserved PTFs, so do as expected */
if PTFs < !Vars.!Reserved then PTFs=!Vars.!Reserved

if Debug then say '< _minCount' PTFs
return PTFs    /* _minCount */

/*---------------------------------------------------------------------
 * --- determine how to distribute parts among PTFs
 * Returns nothing
 * Args: /
 */
_distribute: PROCEDURE EXPOSE ExecName Debug !Vars.
if Debug then say '> _distribute'
OK=0  /* FALSE */          /* assume we need more than minCount PTFs */

PTFs=_minCount()                 /* determine minimum number of PTFs */

do until OK                   /* repeat until we can place all parts */
  !ptfParts.=''                                         /* init stem */
  !ptfFull.=0  /* FALSE */                              /* init stem */
  PTF=1                                      /* start with first PTF */

  !ptfLines.1=!Vars.!Hdr1    /* prime line count with header size */
  do T=2 to PTFs; !ptfLines.T=!Vars.!Hdr2; end

  do T=1 to !Vars.!Parts.0                      /* process all parts */
    Added=0  /* FALSE */             /* we did not yet add this part */

    do S=1 to PTFs                      /* try every PTF until added */
      if \!ptfFull.PTF & (!ptfLines.PTF + !Vars.!Lines.T < 5000000)
      then do                /* yes, this PTF has room for this part */
        Added=1  /* TRUE */
        !ptfLines.PTF=!ptfLines.PTF + !Vars.!Lines.T
        !ptfParts.PTF=!ptfParts.PTF left(!Vars.!Parts.T,8)
        if words(!ptfParts.PTF) = 900 then !ptfFull.PTF=1  /* TRUE */
      end    /* */

      PTF=PTF+1                                    /* go to next PTF */
      if PTF > PTFs then PTF=1
      if Added then leave  /* done with this one */  /* LEAVE LOOP S */
    end    /* loop S */

    /* unable to add anywhere means PTF count was wrong */
    if \Added then leave                             /* leave loop T */
  end    /* loop T */

  if Added                                     /* everything added ? */
  then OK=1  /* TRUE */
  else do                  /* try again with an extra PTF in the mix */
    PTFs=PTFs+1
    if Debug then say '. retry with' PTFs 'PTFs'
  end    /* */
end    /* until OK */

/* write result to stdout, line 1 has parts for PTF 1, line 2 ... */
if Debug
then do T=1 to PTFs
  say '. PTF' T':' words(!ptfParts.T) 'parts,' !ptfLines.T 'lines'
end    /* Debug, loop T */
do T=1 to PTFs
  say !ptfParts.T
end    /* loop T */

if Debug then say '< _distribute'
return    /* _distribute */

