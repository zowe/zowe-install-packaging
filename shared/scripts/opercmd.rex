/* REXX */
/*
 * This program and the accompanying materials are made available
 * under the terms of the Eclipse Public License v2.0 which
 * accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project. 2018, 2019
 */
/*
 *% Issue an operator command and trap output (sent to stdout).
 *% Note: debug adds lines starting with >, ., or <.
 *%
 *% Arguments:
 *% -a dsn   (optional) generate SETPROG APF,ADD command for data set
 *%          cmd is ignored when this option is specified
 *% -c name  (optional) console name, default user ID
 *% -d       (optional) enable debug messages
 *% -w time  (optional) wait time (in sec), 0 blocks output, default 1
 *% cmd      command to execute
 *%
 *% Return code:
 *% 0: command issued (note, command itself might have failed)
 *% 1: error issuing command
 *%
 *% Requirements:
 *% - a RACF profile that protects the console command MUST exist
 *%   (if not: IEE345I ...  AUTHORITY INVALID, FAILED BY MVS)
 *%   class OPERCMDS, profile MVS.** & JES%.**
 *% - user must be allowed to create an EMCS console
 *%   class OPERCMDS, profile MVS.MCSOPER.console
 *%
 *% Additional requirements when using SDSF to issue the command:
 *% - user must be authorized to use ISFSLASH, SDSF REXX interface to
 *%   issue operator command
 *%   class SDSF, profile ISFOPER.SYSTEM
 *%
 *% Additional requirements when using TSO to issue the command:
 *% - user must be allowed to access console via TSO
 *%   class TSOAUTH, profile CONSOLE
 *% - user should be allowed to list TSO PARMLIB definitions (optional)
 *%   class TSOAUTH, profile PARMLIB
 *% - commands are grouped by impact and target, the EMCS console must
 *%   be allowed to issue commands of the given group
 *%   AUTH field of OPERPARM segment of user profile
 */
/*
 * docu in "SDSF Operation and Customization (SA23-2274)"
 * docu in "TSO/E System Programming Command Reference (SA32-0974)"
 * docu in "TSO/E Command Reference (SA32-0975)"
 * docu in "TSO/E REXX Reference (SA32-0972)"
 *
 * Useful reading:
 * - z/OS MVS > z/OS MVS Planning: Operations > Examples and MVS
 *   planning aids for operations > Controlling extended MCS consoles
 *   using RACF
 * - z/OS TSO/E > z/OS TSO/E System Programming Command Reference >
 *   Command syntax > CONSOLE command
 * - SDSF > z/OS SDSF Operation and Customization > Protecting SDSF
 *   functions > MVS and JES commands on the command line
 */
/* user variables ...................................................*/

/* system variables .................................................*/
Failure=1  /* TRUE */                              /* assume failure */
Debug=0  /* FALSE */                     /* assume not in debug mode */
Dsn=''                            /* data set to make APF authorized */
ConsoleCmd=''                                  /* command to execute */
ConsoleName=''                           /* non-default console name */
ConsoleDelay=''                    /* non-default response wait time */
cRC.=0                                    /* prime return codes to 0 */

/* system code ......................................................*/
parse source . . ExecName . . . . ExecEnv .         /* get exec info */
ExecName=substr(ExecName,lastpos('/',ExecName)+1)  /* $(basename $0) */

/* get startup arguments */
parse arg Args                          /* get all startup arguments */

do while Args \= ''
  parse var Args Action Args                   /* cut first argument */

  select                                           /* process option */
    when Action == '-a' then parse var Args Dsn Args
    when Action == '-c' then parse var Args ConsoleName Args
    when Action == '-d' then Debug=1  /* TRUE */
    when Action == '-w' then parse var Args ConsoleDelay Args
    otherwise              /* not an option, must be part of command */
      ConsoleCmd=Action Args            /* put command back together */
      leave                                            /* LEAVE LOOP */
  end    /* select */
end    /* until NoOption */

if Debug then do; say ''; parse arg Args; say '>' ExecName Args; end

/* special command support */
if Dsn \= '' then ConsoleCmd=_apf(Dsn)
/*
 * APF ADD command has two syntaxes, depending on SMS being involved.
 * By adding the determination logic here we avoid duplication in all
 * callers.
 */

/* input validation */
if ConsoleCmd = ''
then do
  say '. ** ERROR no operator command provided'
  parse arg Args
  say '.' ExecName Args
  /* change boolean into RC, with 0 inidcating success, 1 failure */
  if Debug then say '<' ExecName Failure
  exit Failure                                      /* LEAVE PROGRAM */
end    /* */

/* TODO add option validation
 *      - console name 2-8 chars, starting with A-Z, or @#$
 *      - delay is whole number >= 0, max ?
 */

/* . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . */

/* enable SDSF ISFCALL environment */
cRC.isfInit=isfcalls('ON')
if cRC.isfInit == 0
then do                                    /* issue command via SDSF */
  cRC.isfCmd=_sdsfConsoleCmd(ConsoleCmd,ConsoleName,ConsoleDelay)
  Failure=(cRC.isfCmd > 4)
  call isfcalls 'OFF'                       /* ignore possible error */
end    /* SDSF */
else if Debug then say '. isfcalls RC' cRC.isfInit ,
                       _isfcallsText(cRC.isfInit)

/* FIXME: get TSO based console to work
 *   in USS console only stays active within _tsoCmd, so we can not
 *   prep the console or grab the output.
 * IDEA: if USS and tsoConsoleON is successful (now we know permits 
 *   seem good), create a temp dataset with minuature rexx that preps 
 *   console, executes command, traps output and uses say to get it to 
 *   stdout so that we can grab it, and then deactivates console.
 * OTHER IDEA: leverage Legacy ISPF Gateway to drive TSO console
 */
if Failure                                    /* only if SDSF failed */
then do
  call outtrap 'Line.','*','NOCONCAT'         /* trap TSO cmd output */

  parse value _tsoConsoleON(ConsoleName) with cRC.tsoInit tsoInitRsn
  if cRC.tsoInit == 0
  then do
    parse value _tsoConsoleCmd(ConsoleCmd,ConsoleDelay) ,
           with cRC.tsoCmd tsoCmdRsn
    Failure=(cRC.tsoCmd > 0)
    call _tsoConsoleOFF                     /* ignore possible error */
  end    /* init success */

  call outtrap 'OFF'
end    /* TSO */

if Failure
then do
  say '** ERROR not able to execute operator command "'ConsoleCmd'"'
  if cRC.isfInit > 0
    then say 'SDSF init RC'cRC.isfInit _isfcallsText(cRC.isfInit)
    else say 'SDSF command RC'cRC.isfCmd _isfslashText(cRC.isfCmd)

  if cRC.tsoInit > 0
  then if cRC.tsoInit == 1
    then say 'CONSOLE ACTIVATE RC'tsoInitRsn _consoleText(tsoInitRsn)
    else say 'CONSPROF RC'tsoInitRsn _consprofText(tsoInitRsn)
  else if cRC.tsoCmd == 1
    then say 'CONSOLE SYSCMD RC'tsoCmdRsn _consoleText(tsoCmdRsn)
    else say 'GETMSG RC'tsoCmdRsn _getmsgText(tsoCmdRsn)
end    /* */

/* change boolean into RC, with 0 inidcating success, 1 failure */
if Debug then say '<' ExecName Failure
exit Failure                                        /* LEAVE PROGRAM */

/*---------------------------------------------------------------------
 * --- Issue operator command via SDSF
 * Returns return code
 * Args:
 *  Cmd  : operator command to issue
 *  Name : console name, default user ID
 *  Delay: response wait time (sec), 0 blocks output, default 1 sec
 *
 * sample output:
 * ----+----1----+----2----+----3----+----4----+----5----+----6----+---
 * S0W1      2019168  20:09:41.89             ISF031I CONSOLE IBMUSER ACTIVATED
 * S0W1      2019168  20:09:41.89            -D T
 * S0W1      2019168  20:09:41.90  TSU04192   IEE136I LOCAL: TIME=20.09.41 DATE=2019.168  UTC: TIME=02.09.41 DATE=2019.169
 *
 * S0W1      2019168  20:10:37.23             ISF031I CONSOLE IBMUSER ACTIVATED
 * S0W1      2019168  20:10:37.23            -D TN
 * S0W1      2019168  20:10:37.25  TSU04192   IEE305I D        COMMAND INVALID
 */
_sdsfConsoleCmd: PROCEDURE EXPOSE ExecName ExecEnv Debug
parse arg Cmd,Name,Delay
if Debug then say '> _sdsfConsoleCmd' Cmd','Name','Delay

/* ISFCONMOD is ON by default, so SDSF will use an alternate
   console name if the current one is already taken */
if Name \= '' then ISFCONS=Name
if Delay \= '' then ISFDELAY=Delay
Cmd.1=Cmd            /* use stem method to support blanks in command */
Cmd.0=1
Option='WAIT'
/*Option=Option 'VERBOSE'*/ /* extra ISFMSG2. details */    /* trace */

address SDSF ISFSLASH "(Cmd.) ("Option")"
cRC=rc
/*
 * Note that a return code of 0 indicates that SDSF successfully
 * processed the ISFSLASH command. It does not indicate that specific
 * functions were authorized or that commands were executed.
 */
if Debug then say '. isfslash RC' cRC _isfslashText(cRC)
/*say '. isfmsg' ISFMSG*/                                   /* trace */
/*do T=1 to SFMSG2.0; say '. isfmsg2' ISFMSG2.T; end*/      /* trace */

if cRC <= 4
  then do T=1 to ISFULOG.0; say ISFULOG.T; end
  else if Debug then do T=1 to ISFULOG.0; say '.' ISFULOG.T; end

if Debug then say '< _sdsfConsoleCmd' cRC
return cRC    /* _sdsfConsoleCmd */

/*---------------------------------------------------------------------
 * -- Initialize TSO console
 * Returns return and reason code
 *  return code: 0 or ID for command that failed
 *               1: CONSOLE ACTIVATE
 *               2: CONSPROF
 *  reason code: 0 or return code of failed command
 * Args:
 *  Name : console name, default user ID
 *
 * assumes caller did outtrap('Line.','*','NOCONCAT')
 *
 * SOLDISPLAY solicited messages are shown (YES) or stored (NO)
 * SOLNUM     maximum number of solicited messages stored in table
 */
_tsoConsoleON: PROCEDURE EXPOSE ExecName ExecEnv Debug SolMsg
parse arg Name
if Debug then say '> _tsoConsoleON' Name

cRC=0; cRsn=0                                      /* assume success */
SolMsg=''
parse value Name userid() with Name .      /* default: Name=userid() */

/* activate console */

cRsn=_tsoCmd("CONSOLE ACTIVATE,NAME("Name")")               /* try 1 */
select
when cRsn = 0  then nop                                  /* all good */
when cRsn < 0  then cRC=1          /* _tsoCmd() failure, not CONSOLE */
when cRsn = 36 then cRC=1    /* user does not have CONSOLE authority */
otherwise     /* try 1 failed, try again with different console name */
  /*
   * sample error - console name already in use:
   * "CONSOLE ACTIVATE,NAME(ONNO)" ended with RC 40
   * IKJ55303I THE CONSOLE COMMAND HAS TERMINATED.+
   * IKJ55303I AN ERROR OCCURRED DURING CONSOLE INITIALIZATION.  THE
   * MCSOPER RETURN CODE WAS X'00000004' AND THE REASON CODE WAS
   * X'00000000'.
   */
  MaxTries=5
  do T=2 to MaxTries
    Name2=strip(left(Name || random(99999),8),'T')
    cRsn=_tsoCmd("CONSOLE ACTIVATE,NAME("Name2")")
    if cRsn == 0 then leave                            /* LEAVE LOOP */
  end    /* loop T */

  if T > MaxTries then cRC=1   /* cRsn still has CONSOLE ACTIVATE RC */
end    /* select */

/* set console properties */

if cRC == 0                               /* only if no error so far */
then do
  /* sysvar('SOLNUM') returns wrong value in USS, pull from CONSPROF */

  /* get current values */
  cRsn2=_tsoCmd("CONSPROF")
/* sample output: 
IKJ55351I SOLDISPLAY(YES) SOLNUM(1000) UNSOLDISPLAY(YES) UNSOLNUM(1000)    
*/
  if cRsn2 == 0
  then do
    /* save current values */
    parse var Line.1 . 'SOLDISPLAY(' SolDisp ') SOLNUM(' SolNum ')' .
    SolMsg='SOLDISPLAY('SolDisp') SOLNUM('SolNum')'
    if Debug then say '. (init)' SolMsg

    /* get maximum SOLNUM value, current value is default */
    call _tsoCmd "PARMLIB LIST(CONSOLE)"         /* OK if this fails */
    interpret "parse var Line."Line.0" . 'MAXSNUM' MaxSolNum ."
    parse value MaxSolNum SolNum with MaxSolNum .   /* current value */
    if Debug then say '. MaxSolMsg='MaxSolNum       /* is default    */

    /* set table to max size and request message storage in table */
    cRsn=_tsoCmd("CONSPROF SOLDISPLAY(NO) SOLNUM("MaxSolNum")")
    if cRsn <> 0 then cRC=2
  end    /* CONSPROF successful */
end    /* set console properties */

if Debug then say '< _tsoConsoleON' cRc cRsn
return cRc cRsn    /* _tsoConsoleON */

/*---------------------------------------------------------------------
 * --- Issue operator command via TSO
 * Returns return and reason code
 *  return code: 0 or ID for command that failed
 *               1: CONSOLE SYSCMD
 *               2: GETMSG
 *  reason code: 0 or return code of failed command
 * Args:
 *  Cmd  : operator command to issue
 *  Delay: response wait time (sec), 0 blocks output, default 1 sec
 *
 * assumes caller did outtrap('Line.','*','NOCONCAT')
 *
 * sample output:
 * ----+----1----+----2----+----3----+----4----+----5----+----6----+---
 * TODO sample tsoConsoleCmd D T & D TN output
 */
_tsoConsoleCmd: PROCEDURE EXPOSE ExecName ExecEnv Debug
parse arg Cmd,Delay
if Debug then say '> _tsoConsoleCmd' Cmd','Delay

cRC=0; cRsn=0                                      /* assume success */
parse value Delay '1' with Delay .               /* default: Delay=1 */

/* create unique Command And Response Token (CART) */
if digits() < 5 then numeric digits 5
Cart='TSO'random(99999)

cRsn=_tsoCmd("CONSOLE SYSCMD("Cmd") CART('"Cart"')")
/*
 * Note that a return code of 0 indicates that TSO successfully
 * processed the CONSOLE SYSCMD command. It does not indicate that the
 * console command was executed.
 */
if cRsn > 0
then cRC=1
else do
  if Delay > 0
  then do
    Cons.0=0
    cRsn=getmsg('Cons.','SOL',Cart,,Delay)
    if cRsn == 0
    then do T=1 to Cons.0; say Cons.T; end
    else do
      cRC=2
      if Debug then do T=1 to Cons.0; say '.' Cons.T; end
    end    /* */
  end    /* */
end    /* */

if Debug then say '< _tsoConsoleCmd' cRc cRsn
return cRc cRsn    /* _tsoConsoleCmd */

/*---------------------------------------------------------------------
 * -- Deactivate TSO console & restore settings
 * Returns nothing
 * Args:
 *  /
 *
 * assumes caller did outtrap('Line.','*','NOCONCAT')
 */
_tsoConsoleOFF: PROCEDURE EXPOSE ExecName ExecEnv Debug SolMsg
if Debug then say '> _tsoConsoleOFF'

call _tsoCmd "CONSPROF" SolMsg              /* ignore possible error */
call _tsoCmd "CONSOLE DEACTIVATE"           /* ignore possible error */

if Debug then say '< _tsoConsoleOFF'
return    /* _tsoConsoleOFF */

/*---------------------------------------------------------------------
 * -- Build APF ADD command
 * Returns string
 * Args:
 *  Dsn: name of data set to be marked APF authorized
 *
 * assumes caller did outtrap('Line.','*','NOCONCAT')
 */
_apf: PROCEDURE EXPOSE ExecName ExecEnv Debug Line.
parse upper arg Dsn
if Debug then say '> _apf' Dsn

cRC=_tsoCmd("LISTDS '"Dsn"' LABEL")
/*
 *  sample output:
 * listds 'IBMUSER.ZWE.SZWEAUTH'
 * IBMUSER.ZWE.SZWEAUTH
 * --RECFM-LRECL-BLKSIZE-DSORG
 *   U     **    6999    PO
 * --VOLUMES--
 *   U00230
 * --FORMAT 1 DSCB--
 * F1 E4F0F02F2F3F0 0001 750165 000000 01 00 00 C9C2D4D6E2E5E2F24040404040
 * 77004988000000 0200 C0 00 1800 0000 00 0000 82 80000005 000000 0000 0000
 * 0100003200020032000B 00000000000000000000 00000000000000000000 0000000000
 */

/* get volser */
if cRC == 0
then do
  do T=1 to Line.0
    if strip(Line.T) == '--VOLUMES--' then leave       /* LEAVE LOOP */
  end    /* */

  if T >= Line.0
  then cRC=-1
  else do
    T=T+1
    parse var Line.T Volser .
  end    /* volser found */

  if Debug then say '. Volser='Volser
end    /* volser */

/* get SMS status */
if cRC == 0
then do
  do T=1 to Line.0
    if strip(Line.T) == '--FORMAT 1 DSCB--' then leave /* LEAVE LOOP */
  end    /* */

  if T >= Line.0
  then cRC=-2
  else do
    call value 'Line.'line.0+1,'--'       /* add stopper line at end */
    DSCB=''
    T=T+1
    do until left(Line.T,2) == '--'
      DSCB=DSCB || Line.T
      T=T+1
    end    /* */
    /*if Debug then say '. DSCB='DSCB*/                     /* debug */

    /* Get DS1SMSFG flag byte (see "DFSMSdfp Advanced Services") */
    if length(DSCB) < 79
    then cRC=-3
    else do
      DS1SMSFG=substr(DSCB,77,2) /* sample value: 88 */
      if Debug then say '. DS1SMSFG='DS1SMSFG
      /* DS1SMSDS (0x80) - System managed data set */
      SMS=(bitand(x2c(DS1SMSFG),'80'x) == '80'x)
      if Debug then say '. SMS='SMS
    end    /* DSCB valid */
  end    /* DSCB found */
end    /* SMS */

/* create command */
if cRC == 0
then if SMS
  then Cmd='SETPROG APF,ADD,DSN='Dsn',SMS'
  else Cmd='SETPROG APF,ADD,DSN='Dsn',VOL='Volser
else do
  Cmd=''
  /* TODO add error reporting */
end    /* */

if Debug then say '< _apf' Cmd
return Cmd    /* _apf */

/*---------------------------------------------------------------------
 * --- Execute TSO command
 * Returns return code
 * Args:
 *  Cmd: command to execute
 *
 * assumes caller did outtrap('Line.','*','NOCONCAT')
 *
 * TSO command is prefixed with "address TSO" for usage in z/OS UNIX
 */
_tsoCmd: PROCEDURE EXPOSE ExecName ExecEnv Debug Line.
parse arg Cmd
if Debug then say '> _tsoCmd' Cmd

if ExecEnv == 'OMVS'        /* cmd,stdin,stdout,stderr[,stdenv] */
then cRC=bpxwunix('tsocmd "'Cmd'"',,Line.,Trash.)
else do                                       
  "Cmd"
  cRC=rc
end    /* */

if Debug
then do
  say '. "'Cmd'" ended with RC' cRC
  do T=1 to Line.0; say '.' Line.T; end
end    /* */

if Debug then say '< _tsoCmd' cRC
return cRC    /* _tsoCmd */

/*---------------------------------------------------------------------
 * --- Get text describing a given ISFCALLS return code
 * Returns string
 * Args:
 *  1: ISFCALLS return code
 *
 * do NOT call from a routine that has values for
 * _txt.
 *
 * docu in "SDSF Operation and Customization (SA23-2274)"
 */
_isfcallsText: /* NO PROCEDURE */
  _txt. ='Undocumented error code'
  _txt.0='Function completed successfully'
  _txt.1='Host command environment query failed, environment not added'
  _txt.2='Host command environment add failed'
  _txt.3='Host command environment delete failed'
  _txt.4='Options syntax error, or options not defined'
return value('_txt.'arg(1))    /* _isfcallsText */

/*---------------------------------------------------------------------
 * --- Get text describing a given ISFSLASH return code
 * Returns string
 * Args:
 *  1: ISFSLASH return code
 *
 * do NOT call from a routine that has values for
 * _txt.
 *
 * docu in "SDSF Operation and Customization (SA23-2274)"
 */
_isfslashText: /* NO PROCEDURE */
  _txt.  ='Undocumented error code'
  _txt.0 ='The request completed successfully'
  _txt.4 ='The request completed successfully but not all functions' ,
          'were performed'
  _txt.8 ='An incorrect or invalid parameter was specified for an' ,
          'option or command'
  _txt.12='A syntax error occurred in parsing a host environment' ,
          'command'
  _txt.16='The user is not authorized to invoke SDSF'
  _txt.20='A request failed due to an environmental error'
  _txt.24='Insufficient storage was available to complete a request'
return value('_txt.'arg(1))    /* _isfslashText */

/*---------------------------------------------------------------------
 * --- Get text describing a given CONSOLE return code
 * Returns string
 * Args:
 *  1: CONSOLE return code
 *
 * do NOT call from a routine that has values for
 * _txt.
 *
 * docu in "TSO/E System Programming Command Reference (SA32-0974)"
 */
_consoleText: /* NO PROCEDURE */
  _txt.  ='Undocumented error code'
  _txt.0 ='Processing successful'
  _txt.4 ='The session is already active and the request is activation'
  _txt.8 ='User interrupted command'
  _txt.12='An exit invocation failed'
  _txt.16='Recovery could not be established'
  _txt.20='There is no active CONSOLE session and the request is not' ,
          'activation'
  _txt.24='Request denied, deactivation in progress'
  _txt.28='An abend occurred during processing'
  _txt.32='PUTGET failed'
  _txt.36='User does not have CONSOLE authority'
  _txt.40='Activation failed'
  _txt.44='An installation exit requested termination'
  _txt.48='Deactivation failed'
  _txt.52='Initialization failed'
  _txt.56='NAME specified when already active'
  _txt.60='Parsing failed'
  _txt.64='The system command was too long'
  _txt.68='No CNCCB exists'
  _txt.72='Unsupported z/OS level'
return value('_txt.'arg(1))    /* _consoleText */

/*---------------------------------------------------------------------
 * --- Get text describing a given CONSPROF return code
 * Returns string
 * Args:
 *  1: CONSPROF return code
 *
 * do NOT call from a routine that has values for
 * _txt.
 *
 * docu in "TSO/E System Programming Command Reference (SA32-0974)"
 */
_consprofText: /* NO PROCEDURE */
  _txt.  ='Undocumented error code'
  _txt.0 ='Processing successful'
  _txt.4 ='Command is invoked without APF authorization'
  _txt.8 ='Command is invoked without console autority'
  _txt.12='An error occurred during command buffer parsing'
  _txt.16='Recovery could not be established'
  _txt.20='An abend occurred during processing'
  _txt.24='An installation exit requested termination'
  _txt.28='An installation exit abended'
  _txt.32='No CNCCB exists'
  _txt.72='Unsupported z/OS level'
return value('_txt.'arg(1))    /* _consprofText */

/*---------------------------------------------------------------------
 * --- Get text describing a given GETMSG return code
 * Returns string
 * Args:
 *  1: GETMSG return code
 *
 * do NOT call from a routine that has values for
 * _txt.
 *
 * docu in "TSO/E REXX Reference (SA32-0972)"
 */
_getmsgText: /* NO PROCEDURE */
  _txt.  ='Undocumented error code'
  _txt.0 ='Processing successful, the message is retrieved'
  _txt.4 ='Processing successful, but the message is not retrieved'
  _txt.8 ='Processing successful, but message retrieval was interrupted'
  _txt.12='Processing not successful, there is no active console'
  _txt.16='Processing not successful, the console was deactivated',
          'while processing'
return value('_txt.'arg(1))    /* _getmsgText */

/*---------------------------------------------------------------------
 * --- Display script usage information
 * Returns nothing
 */
_displayUsage: PROCEDURE EXPOSE ExecName ExecEnv
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
