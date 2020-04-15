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
Debug=0  /* FALSE */                     /* assume not in debug mode */

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

/* Gather variable names from Input */
xmlVariables.0 = "initiate" /* Initiate a XML variables array */
xmlIndex = 0 /* XML arrays index */
/* Loop through the xml to collect variable names */
do while lines(Input) > 0
  line_str = linein(Input)
  do while line_str <> ''
    parse var line_str '<' tag '='
    if(tag == "variable name") then /* Store the found variable names in array */
    do
      parse var line_str 'name="' xmlVariables.xmlIndex '"' line_str
      xmlIndex = xmlIndex + 1
    end
    else /* If no variable name null the line */
    do
      line_str = ''
    end
   end
end

/* copy to iFile. so that File. is free for reading include file */
do F=0 to File.0 ; iFile.F=File.F ; end

T=0  /* output line number */
/* loop through input to create output */
do I=1 to iFile.0
  iFile.I=_substitute('utf-8','IBM-1047',iFile.I)

  /* add include file ? */
  parse var iFile.I Before '###' Include '###' After
  if Include = ''
  then do                                         /* no include file */
    T=T+1 ; oFile.T=iFile.I
  end    /* no include */
  else do                                        /* add include file */
    if Debug then say '. including' Include

    if \_readFile(Include)
      then exit 8  /* error already reported */     /* LEAVE PROGRAM */

    /* Check variables in VLT file(s) */
    checkFailed = 0
    do while lines(Include) > 0
      check_str = linein(Include)
      totalMatchesCount = 0 /* The number of matches so far */
      varcount = 0
      vtlIndex = 0
      do while check_str <> ''
        parse var check_str pre '$' post
        currentVar = '' /* Initiate empy current variable*/
        if(length(post) > 0 ) then do
          varcount = varcount + 1
          parse var post leftBrace '{' possibleVar "}" Other
          if(length(possibleVar) > 0) then do
            currentVar = possibleVar
          end
          else do
            parse var check_str '$$' doublePref1 " " Other
            parse var check_str '$&' doublePref2 " " Other
            parse var check_str '$' possiblyOk " " Other
            if(length(doublePref1) > 0) | (check_str == "$$") | (length(doublePref2) > 0) then do
              currentVar = ''
            end
            else do
              currentVar = possiblyOk
            end
          end
        end
        check_str = ''
      end
      if(length(currentVar) > 0) then do
        vtlIndex = vtlIndex + 1
        count = 0
        noMatch = 1
        do until count >= xmlIndex
          if (currentVar == xmlVariables.count) then do
            totalMatchesCount = totalMatchesCount + 1
            noMatch = 0
          end
          count = count + 1
        end
        if (noMatch == 1) then do
          say 'ERROR: no variable with name "' currentVar '" was found in the ' Input ' template!'
          checkFailed = 1
        end
      end
    end
    if(checkFailed == 1) then do
        exit 8
    end

    select
    when File.0 = 0 then do
      say '** ERROR' ExecName 'include file' Include 'is empty'
      exit 8                                        /* LEAVE PROGRAM */
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

/* copy to File., expected bu _writeFile() */
do F=0 to oFile.0 ; File.F=oFile.F ; end

/* save result */
if \_writeFile(Output)
  then exit 8  /* error already reported */         /* LEAVE PROGRAM */

if Debug then say '<' ExecName '0'
exit 0                                              /* LEAVE PROGRAM */

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

