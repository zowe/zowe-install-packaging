/* REXX */
/*
 * This program and the accompanying materials are made available
 * under the terms of the Eclipse Public License v2.0 which
 * accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project. 2019, 2020
 */
/*
 *% Update skeleton zOSMF workflow file.
 *% Note: debug messages in starting with >, . or <.
 *%
 *% Arguments:
 *% -d         (optional) enable debug messages
 *% -i input   skeleton file to update
 *% -o output  updated skeleton file
 *%
 *% Return code:
 *% 0: output created
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
Input='./smpe_workflow.xml'                    /* default input file */
Output='./ZWEWRF01.xml'                       /* default output file */

/* system variables .................................................*/
cRC=0                                                 /* return code */
Debug=0  /* FALSE */                     /* assume not in debug mode */
xmlList=''                               /* init list to null string */
xmlVars.=0  /* FALSE */                /* init table to FALSE values */
vtlVars.=0  /* FALSE */                /* init table to FALSE values */

/* system code ......................................................*/
/* trace r */
SIGNAL ON NOVALUE NAME CONDITION_TRAP    /* activate condition traps */
SIGNAL ON SYNTAX NAME CONDITION_TRAP     /* that will kill the exec  */

parse source . . ExecName . . . . ExecEnv .         /* get exec info */
ExecName=substr(ExecName,lastpos('/',ExecName)+1)  /* $(basename $0) */

/* get startup arguments */
parse arg Args                          /* get all startup arguments */

do while Args \= ''
  parse var Args xArg Args                     /* cut first argument */

  select                                           /* process option */
  when xArg == '-d' then Debug=1  /* TRUE */
  when xArg == '-i' then parse var Args Input Args
  when xArg == '-o' then parse var Args Output Args
  otherwise
    say '** ERROR' ExecName 'invalid startup argument' xArg
    exit 8                                          /* LEAVE PROGRAM */
  end    /* select */
end    /* while Args */

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
  exit 8                                            /* LEAVE PROGRAM */
end    /* */

/* place skeleton in stem "File." */
if \_readFile(Input)
  then exit 8  /* error already reported */         /* LEAVE PROGRAM */

/* gather variable names from Input (XML workflow) */
/* <variable name="ibmTemplate" scope="instance" visibility="public">*/
do F=1 to File.0
  parse var File.F . '<variable name="' Name '"' .
  if Name <> ''                             /* variable definition ? */
  then if xmlVars.Name     /* already defined ? (value is a boolean) */
    then do
      say '** ERROR' ExecName 'duplicate variable definition for' ,
        Name 'in' Input 'at line' F
      cRC=8              /* continue processing to find other errors */
    end    /* */
    else do                           /* table with variable name as */
      xmlVars.Name=1  /* TRUE */      /* index, value set to TRUE    */
      xmlList=xmlList Name                 /* list of variable names */
    end    /* */
  else do
    /* variable definitions are done when step definitions start */
    /* <step name="define_variables" optional="false"> */
    parse var File.F . '<step name="' Name '"' .
    if Name <> '' then leave                         /* LEAVE LOOP F */
  end    /* */
end    /* loop F */
if Debug then say '. workflow variables:'xmlList

/* copy to iFile. so that File. is free for reading include file */
do F=0 to File.0 ; iFile.F=File.F ; end

T=0  /* output line number */
/* loop through input to create output */
do I=1 to iFile.0
  iFile.I=_substitute('utf-8','IBM-1047',iFile.I)

  /* add include file ? */
  /* <inlineTemplate substitution="true">###...###</inlineTemplate> */
  parse var iFile.I Before '###' Include '###' After
  if Include = ''
  then do                                         /* no include file */
    T=T+1 ; oFile.T=iFile.I
  end    /* no include */
  else do                                        /* add include file */
    if Debug then say '. including' Include

    if \_readFile(Include)
      then exit 8  /* error already reported */     /* LEAVE PROGRAM */

    /* gather variables used in include file (VLT) */
    do F=1 to File.0
      cRC=max(cRC,_getVars(File.F,F,Include))
    end /* loop F */
 
    /* add include file to workflow */
    select
    when File.0 = 0 then do
      say '** ERROR' ExecName 'include file' Include 'is empty'
      cRC=8              /* continue processing to find other errors */
    end    /* */
    when File.0 = 1 then do
      File.1=_substitute71('&','&amp;',File.1)
      T=T+1 ; oFile.T=Before || File.1 || After
    end    /* */
    otherwise
      File.1=_substitute71('&','&amp;',File.1)
      T=T+1 ; oFile.T=Before || File.1

      do F=2 to File.0-1
        File.F=_substitute71('&','&amp;',File.F)
        T=T+1 ; oFile.T=File.F
      end    /* loop F */

      /* F=File.0 */  /* already so after loop */
      File.F=_substitute71('&','&amp;',File.F)
      T=T+1 ; oFile.T=File.F || After
    end    /* select */
  end    /* add include */
end    /* loop I */

oFile.0=T
if Debug then say '.' oFile.0 'output lines'

/* verify that all workflow variables are used */
do while xmlList <> ''
  /* cut first word from list and place in Name */
  parse var xmlList Name xmlList         
  
  if \vtlVars.Name   /* used in include files ? (value is a boolean) */
  then do
    say '** ERROR' ExecName 'variable' Name 'in' Input 'is not used'
    cRC=8                /* continue processing to find other errors */
  end    /* */
end    /* while xmlList */

/* copy to File., expected by _writeFile() */
do F=0 to oFile.0 ; File.F=oFile.F ; end

/* save result */
if \_writeFile(Output)
  then exit 8  /* error already reported */         /* LEAVE PROGRAM */

if Debug then say '<' ExecName cRC
exit cRC                                            /* LEAVE PROGRAM */

/*---------------------------------------------------------------------
 * -- gather variable names used in VTL include file
 * Returns return code
 * Updates vtlVars.
 * Args:
 *  String: string to process
 *  Line  : line number in file
 *  File  : file holding string
 */
_getVars: PROCEDURE EXPOSE Debug ExecName Input xmlVars. vtlVars.
parse arg String,Line,File
cRC=0                                                 /* return code */

/* #if has a different variable format */
if left(String,4) == '#if('   
then do                                                    /* '#if(' */
  /* #if($ibmTemplate == 'NO' || !$!ibmTemplate) */
  /* #if( $sysaff and $sysaff != "" and $sysaff != '#sysaff') */ 

  /* replace ! variable names to simplify parsing */
  String=_substitute('$!','$',_substitute('${!','${',String))
  /* replace evaluation characters with blanks to simplify parsing */
  String=translate(String,,'(!=)',' ')
  if Debug then say '. String='String

  Start='$'  
  Stop=' '
end    /* #if( */
else do                                                  /* not #if( */
  /* // SYSAFF=${sysaff}, */
  Start='${'  
  Stop='}'
end    /* not #if( */

do while String <> ''
  /* get first variable name, and trim String to trailing part */
  parse var String . (Start) Name (Stop) String
  
  if Name <> ''                                  /* variable found ? */
  then do                             /* table with variable name as */
    vtlVars.Name=1  /* TRUE */        /* index, value set to TRUE    */
    if \xmlVars.Name            /* is variable defined in workflow ? */
    then do
      say '** ERROR' ExecName 'variable' Name 'on line' Line ,
        'in include file' File 'is not defined in workflow' Input
      cRC=8              /* continue processing to find other errors */
    end    /* oops */
  end    /* variable found */
end    /* while String */
return cRC    /* _getVars */

/*---------------------------------------------------------------------
 * -- Substitute one string with another and keep line within 71 chars
 * Returns input Line (string) with Old replaced by New
 * Args:
 *  Old : word/string to replace
 *  New : replacement word/string
 *  Line: string to process
 */
_substitute71: PROCEDURE EXPOSE Debug ExecName
parse arg Old,New,Line

Line=_substitute(Old,New,Line)
do while length(Line) > 71
  if lastpos('  ',Line) > 0
  then Line=_substitute('  ',' ',Line,lastpos('  ',Line))
  else do
    say '** ERROR' ExecName 'cannot trim line after substitution'
    say '(length' length(Line)')' Line
    exit 8                                          /* LEAVE PROGRAM */
  end    /* */
end    /* while */
return Line    /* _substitute71 */

/*---------------------------------------------------------------------
 * -- Substitute one string with another
 * Returns input Line (string) with Old replaced by New
 * Args:
 *  Old  : word/string to replace
 *  New  : replacement word/string
 *  Line : string to process
 *  Start: (optional) starting position, default 1
 */
_substitute: PROCEDURE EXPOSE Debug
parse arg Old,New,Line,Start
parse value Start '1' with Start .               /* default: Start=1 */

Start=pos(Old,Line,Start)
do while Start > 0
  /* substitute Old with New */
  Line=insert(New,delstr(Line,Start,length(Old)),Start-1)
  if Debug then say '. (substitute) (length' length(Line)')' Line

  /* start after New for next test */
  Start=pos(Old,Line,Start + length(New))
end    /* while */
return Line    /* _substitute */

/*---------------------------------------------------------------------
 * -- Write z/OS UNIX file
 * Returns boolean indicating success (1) or not (0)
 * Assumes the data to be written is in stem "File."
 * Note: writefile has a 1024 char/line limitation
 * Args:
 *  Path   : file to write to
 *  Mode   : (optional) file mode, default 755
 *  Append : (optional) specify 1 to append to existing file
 *  Verbose: (optional) flag to show syscall error message
 *
 * docu in "Using REXX and z/OS UNIX System Services (SA23-2283)"
 */
_writeFile: PROCEDURE EXPOSE Debug ExecName File.
parse arg Path,Mode,Append,Verbose
parse value Mode '755' with Mode .              /* default: Mode=755 */
parse value Append '0' with Append .            /* default: Append=0 */

if Path <> ''
then OK=_syscall('writefile "'Path'"' Mode 'File.' Append,Verbose)
else do
  say '** ERROR' ExecName 'output path cannot be null'
  OK=0  /* FALSE */
end    /* */
return OK    /* _writeFile */

/*---------------------------------------------------------------------
 * -- Read z/OS UNIX file
 * Returns boolean indicating success (1) or not (0)
 * The file is returned in stem "File."
 * Note: readfile has a 1024 char/line limitation
 * Args:
 *  Path   : file to read
 *  Verbose: (optional) flag to show syscall error message
 *
 * docu in "Using REXX and z/OS UNIX System Services (SA23-2283)"
 */
_readFile: PROCEDURE EXPOSE Debug ExecName File.
parse arg Path,Verbose
if Path = '' then do; File.0=0; return 0; end       /* LEAVE ROUTINE */
return _syscall('readfile "'Path'" File.',Verbose)    /* _readFile */

/*---------------------------------------------------------------------
 * --- Execute z/OS UNIX syscall command with basic error handling
 * Returns boolean indicating success (1) or not (0)
 * Assumes caller has EXPOSE Debug ExecName
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
