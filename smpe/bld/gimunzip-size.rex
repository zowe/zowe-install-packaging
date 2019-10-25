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
 *% Estimate the size (in tracks) of the file system needed to
 *% extract GIMZIP output and run GIMUNZIP (result in stdout).
 *% Note: debug adds lines starting with >, . or <.
 *%
 *% Arguments:
 *% -d     (optional) enable debug messages
 *% path   path of GIMZIP pax file            
 *%
 *% Return code:
 *% 0: calculated size is in stdout
 *% 8: error
 */
/* REXX error trap ..................................................*/
signal JUMP_TRAP_CODE                   /* jump over error trap code */
/*
 * Note: - we are dead if we ever get here
 *       - trap code is early in source to ensure REXX can find it
 *       - used fcts are quoted to avoid further scanning of code
 */
CONDITION_TRAP:

Jump="CONDITION"('I')       /* how did we get here, SIGNAL or CALL ? */
Trap="CONDITION"('C')                      /* which trap triggered ? */
Line=sigl                       /* line where the trap was triggered */
xVar="CONDITION"('D')             /* variable that triggered NOVALUE */
xRC=rc           /* RC that triggered SYNTAX/FAILURE/ERROR (decimal) */

say '** ERROR REXX condition trapping ended this program'
say '** ERROR' Jump 'ON' Trap

select
when Trap == 'NOVALUE' then
  say '** ERROR referencing variable' xVar
when Trap == 'SYNTAX' then
  say '** ERROR IRX00'xRC'I RC('xRC')' "ERRORTEXT"(xRC)
otherwise
  say '** ERROR RC' xRC '('"RIGHT"('000'"D2X"("ABS"(xRC)),4)'x)'
end    /* select */     /* FAILURE RC (<0) can be decimal abend code */

say '** ERROR' Line '+++' "SOURCELINE"(Line)
exit 8                                              /* LEAVE PROGRAM */
JUMP_TRAP_CODE:

/* user variables ...................................................*/

/* system variables .................................................*/
Debug=0                                  /* assume not in debug mode */
TracksPerCyl=15                     /* true for all 3390 disk models */

/* system code ......................................................*/
/* trace r */                                                          
SIGNAL ON NOVALUE NAME CONDITION_TRAP    /* activate condition traps */
SIGNAL ON SYNTAX NAME CONDITION_TRAP     /* that will kill the exec  */

parse source . . ExecName . . . . ExecEnv .         /* get exec info */
ExecName=substr(ExecName,lastpos('/',ExecName)+1)  /* $(basename $0) */
numeric digits 20                              /* increase precision */

/* get startup arguments */
parse arg Args                          /* get all startup arguments */

do while Args \= ''
  parse var Args xArg Args                     /* cut first argument */

  select                                           /* process option */
  when xArg == '-d' then Debug=1  /* TRUE */
  otherwise                   /* not an option, must be part of path */
    Path=xArg Args                         /* put path back together */
  end    /* select */
end    /* until NoOption */

if Debug then do; say ''; parse arg Args; say '>' ExecName Args; end

/* enable z/OS UNIX SYSSCALL environment */
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

/* get information on file */
if \SyscallCmd('stat' Path 'st.')
then do
  /* error already reported */
  exit 8                                            /* LEAVE PROGRAM */
end    /* */

if st.1 \= 3                                 /* 1=ST_TYPE, 3=S_ISREG */
then do
  say '** ERROR' ExecName '"'Path'" is not a file'
  exit 8                                            /* LEAVE PROGRAM */
end    /* */

Size=st.8                                               /* 8=ST_SIZE */
if right(Size,1) = 'M'               /* convert megabytes to bytes ? */
  then Size=left(Size,length(Size)-1) * 1024 * 1024
if Debug then say '. Size='Size '(bytes, actual)'

/* . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . */

/*
 * The file system needed to extract the paxed GIMZIP output must be
 * big enough to hold the initial pax file, the readme, the individual
 * GIMZIP archives extracted from the pax file and a work area.
 * The size depends on compression ratios and thus can vary, but
 * measurements for multiple GIMZIP pax files shows that we can
 * estimate the size with polynominals of order 2 (y=ax2+bx+c).
 *      pax size  filesys size (CYL)
 *       (bytes)  actual  calculated
 *        96,768       2           4
 *       161,280       3           5
 *       838,656       7           7
 *       870,912       7           7
 *       999,936       9           8
 *     1,064,448       9           8
 *     1,483,776       9          10
 *     5,031,936      23          24
 *     7,838,208      40          35
 *     8,612,352      33          38
 *    10,160,640      37          44
 *    43,739,136     178         160
 *    64,286,208     224         220
 *    73,866,240     265         245
 * --other formula--
 *   111,412,224     526         532
 *   111,605,760     526         533
 *   524,095,488   2,257       2,071
 *   627,895,296   2,262       2,351
 * 1,092,284,928   3,092       3,075
 */
select
when Size > 100000000 then do
  a=-0.000000000000002
  b=0.000005
  c=0
end
otherwise
  a=-0.00000000000001
  b=0.000004
  c=3
end    /* select */

Cyl=trunc(a*Size**2 + b*Size + c) + 1       /* trunc()+1 to round up */
if Debug then say '. Cyl='Cyl '(cylinders, calculated)'

if ExecEnv = 'TSO' then call syscalls 'OFF' /* ignore possible error */
/* 
 * zFS always increments in CYL but return result in TRACKs as that
 * unit is expected in the Program Directory.
 */
if Debug then say '. Trk='Cyl*TracksPerCyl '(tracks, calculated)'
say Cyl*TracksPerCyl
if Debug then say '<' ExecName 0
exit 0                                              /* LEAVE PROGRAM */

/*-------------------------------------------------------------------*/
SyscallCmd: /* NO procedure */  /* syscall with basic error handling */
/* do NOT call from a routine that has values for                    */
/* _Err. _RC _RetVal _ErrNo _ErrNoJr _Success _Cmd _Verbose          */
/*-------------------------------------------------------------------*/
parse arg _Cmd,_Verbose
parse value _Verbose 1 with _Verbose .           /* default: verbose */
_Success=1  /* TRUE */
_Err.0=0

address SYSCALL _Cmd
parse value rc retval errno errnojr with _RC _RetVal _ErrNo _ErrNoJr

if _RC < 0
then do
  _Success=0  /* FALSE */
  say ''
/* NOTE: caller must store RC if desired */
  say '** ERROR ** syscall command failed:' _Cmd
  select                                               /* REXX error */
  when (_RC < -20) & (_RC > -30) then
    say '** ERROR' ExecName 'argument' abs(_RC)-20 'is in error'
  when _RC = -20 then
    say '** ERROR' ExecName ,
      'unknown SYSCALL command or improper number of arguments'
  when _RC = -3 then
    say '** ERROR' ExecName 'not in SYSCALL environment'
  otherwise
    say '** ERROR' ExecName 'error flagged by REXX language processor'
  end    /* select */
end    /* REXX error */
else if _RetVal == -1
  then do                                              /* UNIX error */
    _Success=0  /* FALSE */
    if _Verbose
    then do                                      /* report the error */
      say ''
/* NOTE: caller must store RC if desired */
      say '** ERROR' ExecName 'syscall command failed:' _Cmd
      say 'ErrNo('_ErrNo') ErrNoJr('_ErrNoJr')'
      address SYSCALL 'strerror' _ErrNo _ErrNoJr '_Err.'
      do T=1 for _Err.0 ; say _Err.T ; end
    end    /* report */
  end    /* UNIX error */
/*else nop */ /* Note: a few cmds use retval <> -1 to indicate error */

drop rc retval errno errnojr /* ensure that the name is used in parse*/
parse value _RC _RetVal _ErrNo _ErrNoJr with rc retval errno errnojr
return _Success    /* SyscallCmd */

