/* REXX */
/*
 * This program and the accompanying materials are made available
 * under the terms of the Eclipse Public License v2.0 which
 * accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project. 2019, [YEAR]
 */
/*
 *% This exec will create a mountpoint, optionally mount a file system
 *% (read/write), and optionally create subdirectories for product
 *% Zowe Open Source Project
 *%
 *% Arguments:
 *% -Debug    (optional) enable debug messages
 *% -Me       (optional) do not issue commands as superuser (UID 0)
 *% ROot=dd   referenced DD name holds the directory which is the base
 *%           for MOUNT and DIRS
 *%           (required when MOUNT is specified, optional otherwise)
 *% DIrs=dd   (optional) referenced DD name holds a list of
 *%           directories to be created
 *%           these directories will be prefixed by the path specified
 *%           in ROOT
 *% MOunt=dsn (optional) mount the specified file system on the path
 *%           specified in ROOT
 *% AGgrgrow  (optional) adds the AGGRGROW parameter during mount to
 *%           allow a zFS file system to take automatic extents
 *%
 *% DDs:
 *% REPORT (optional) a report of the actions done is written to here
 *% ROOT   (optional) holds root path to be created
 *%        - required when MOUNT is specified
 *%        - leading and trailing blanks are ignored
 *%        - path name may not hold embedded blanks
 *%        - multi-line input will be concatenated to a single path name
 *%        - path must be absolute (start with /)
 *%        - path may hold multiple directory names
 *%        - existing directories that do not have at least read &
 *%          search access permission (5) for owner, group, and other,
 *%          will be altered to set the read & search bits for all.
 *%        - missing directories will be created, with permissions 755
 *%          (owner has full access, group and other have read and
 *%          search permits)
 *% DIRS   (optional) holds list of sub-directories to be created
 *%        - DIRS is processed after the optional file system mount
 *%        - each line hold one sub-directory path
 *%        - leading and trailing blanks are ignored
 *%        - path name may not hold embedded blanks
 *%        - path is relative to root path, if ROOT is specified
 *%        - path may hold multiple directory names
 *%        - existing directories that do not have at least read &
 *%          search access permission (5) for owner, group, and other,
 *%          will be altered to set the read & search bits for all.
 *%        - missing directories will be created, with permissions 755
 *%          (owner has full access, group and other have read and
 *%          search permits)
 *%        - the access permission bits for the last directory in the
 *%          path can be specified as second keyword on the line, thus
 *%          altering the 755 default
 *%        - comment lines start with #, data lines my not hold comments
 *%
 *% Return code:
 *% 0:  completed successfully
 *% 4:  warning issued
 *% 8:  processing error
 *% 12: input or exec error
 */
/*
 * Sample JCL:
 * //         SET DSN=my.zfs.file.system
 * //MKDIR    EXEC PGM=IKJEFT01,REGION=0M,COND=(4,LT),
 * // PARM='%xxxMKDIR ROOT=ROOT DIRS=DIRS MOUNT=&DSN AGGRGROW'
 * //SYSEXEC  DD DISP=SHR,DSN=my.exec.library
 * //REPORT   DD SYSOUT=*
 * //SYSTSPRT DD SYSOUT=*
 * //SYSTSIN  DD DUMMY
 * //ROOT     DD *
 *   /my/multiline/
 *   root/directory
 * //DIRS     DD *
 *   # comment line
 *   sub/directory
 *   subdir/with/non-default-permits 777
 */
/* user variables ...................................................*/
DefaultMask=755                       /* default permission bit mask */

/* system variables .................................................*/
cRC=0                                              /* assume success */
Debug=0                                  /* assume not in Debug mode */
Super=1                         /* assume issueing commands as UID 0 */
RootDD=''                                 /* assume no root provided */
FileSys=''                    /* assume no need to mount file system */
DirsDD=''                /* assume no need to create sub-directories */
Grow=''                       /* assume no automatic extents for zFS */
Root=''                                           /* no default root */
Dirs.0=0                               /* no default sub-directories */
Report.=1                         /* initialize all stem fields to 1 */

/* system code ......................................................*/
parse source . . ExecName . . . . ExecEnv .         /* get exec info */
ExecName=substr(ExecName,lastpos('/',ExecName)+1)  /* $(basename $0) */

/* process startup arguments */
parse upper arg Args           /* get startup arguments in uppercase */

say ' '
say '*' ExecName 'started with arguments' Args
say ' '

do while Args <> ''
  parse var Args Action Args                   /* cut first argument */
  parse var Action xKey '=' xValue /* split in key & value if needed */
  if Debug then say '. (args)' Action

  select
  when abbrev('ROOT',xKey,2)     then RootDD=xValue
  when abbrev('DIRS',xKey,2)     then DirsDD=xValue
  when abbrev('MOUNT',xKey,2)    then FileSys=xValue
  when abbrev('AGGRGROW',xKey,2) then Grow='AGGRGROW'
  when abbrev('-DEBUG',xKey,2)   then Debug=1  /* TRUE */
  when abbrev('-ME',xKey,2)      then Super=0  /* FALSE */
  otherwise
    call _displayUsage
    say '** ERROR invalid startup argument "'Action'"'
    cRC=12                 /* do not exit yet, show all errors first */
  end    /* select */
end    /* while Args */

if (FileSys <> '') & (RootDD == '')
then do
  call _displayUsage
  say '** ERROR MOUNT keyword requires ROOT keyword'
  cRC=12                   /* do not exit yet, show all errors first */
end   /* */

if (Grow <> '') & (FileSys == '')
then do
  call _displayUsage
  say '** ERROR AGGRGROW keyword requires MOUNT keyword'
  cRC=12                   /* do not exit yet, show all errors first */
end   /* */

if (RootDD == '') & (FileSys == '') & (DirsDD == '')
then do
  call _displayUsage
  say '** ERROR ROOT, MOUNT, or DIRS keyword is required'
  cRC=12                   /* do not exit yet, show all errors first */
end   /* */

/* process input */
if RootDD <> '' then cRC=max(cRC,_rootDD(RootDD))
if DirsDD <> '' then cRC=max(cRC,_dirsDD(DirsDD))
if FileSys <> ''
then if _dsnExist(FileSys)
  then say '-- will mount file system "'FileSys'"'
  else do
    say '** ERROR cannot locate data set "'FileSys'"'
    say SYSMSGLVL2
    cRC=12                 /* do not exit yet, show all errors first */
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
  say '** ERROR ** unable to establish the SYSCALL environment'
  say 'RC='xRC Text.xRC
  say ' '
  exit 12                                           /* LEAVE PROGRAM */
end    /* */

/* become UID 0 */
if \Super
then eUid=0                      /* set value for cleanup processing */
else do
  /* become UID 0 if possible, requires FACILITY BPX.SUPERUSER permit*/
  address SYSCALL 'geteuid'
  eUid=retval
  /* ignore possible failure, other ways might give permits */
  if eUid <> 0 then address SYSCALL 'seteuid 0'
  if retval == -1
  then do
    say '** WARNING unable to switch to UID 0, continuing with UID' eUid
    cRC=max(cRC,4)
  end    /* */
end    /* become UID 0 */

/* . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . */

/* set umask to allow DefaultMask to stick */
if \_syscall('umask' right(777-DefaultMask,3,'0'))
then do
  say '** ERROR unable to set umask'
  cRC=max(cRC,8)
end    /* */
else do
  /* start processing */
  if Root <> ''
    then cRC=max(cRC,_mkdir(Root))
  if cRC <= 4
    then if FileSys <> ''
      then cRC=max(cRC,_mount(Root,FileSys,Grow))
      else cRC=max(cRC,_mountInfo(Root))
  do T=1 to Dirs.0
    if cRC <= 4
      then cRC=max(cRC,_mkdir(Root,word(Dirs.T,1),word(Dirs.T,2)))
  end    /* loop T */

  if _ddExist('REPORT')
  then do
    cRC=max(cRC,_report('REPORT','keep','Following directories' ,
                        'already exist with proper permissions:'))
    cRC=max(cRC,_report('REPORT','chmod','Changed permission bits of' ,
                        'existing directories:'))
    cRC=max(cRC,_report('REPORT','mkdir','Created the following' ,
                        'directories:'))
    if FileSys <> ''
    then cRC=max(cRC,_report('REPORT','mount','Mounted the following' ,
                             'file system:'))
    else cRC=max(cRC,_report('REPORT','mount','Started directory' ,
                             'creation in the following file system:'))
  end    /* report */
end    /* process payload */

/* . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . */

if eUid <> 0 then address SYSCALL 'seteuid' eUid        /* ignore RC */
if ExecEnv <> 'OMVS' then call syscalls 'OFF'           /* ignore RC */
say ' '
say '*' ExecName 'ended with return code' cRC
say ' '
exit cRC

/*---------------------------------------------------------------------
 * --- Makes a directory path, similar to mkdir -pm
 * Returns return code
 * Updates Report.
 * Args:
 *  Root : Root path, must exist if Dir is specified, can be ''
 *  Dir  : (optional) path to add to Root, can be ''
 *  pBits: (optional) permission bits for last directory in path
 *
 * Since all Dir paths provided to this routine share Root, it is a
 * a waste of resources if we verify Root on each call. Therefore we
 * require that the caller first calls _mkdir(Root) before calling
 * _mkdir(Root,Dir), so that the latter can skip verifying Root.
 */
_mkdir: PROCEDURE EXPOSE Debug Report. DefaultMask
parse arg Root,Dir,pBits
if Debug then say '> _mkdir' Root','Dir','pBits

/* safety net, caller should have done this */
Root=strip(Root,'T','/')        /* strip trailing /, can become null */
Dir=strip(Dir,'L','/')           /* strip leading /, can become null */

/* get existing part of path */
parse value _existPath(Root'/'Dir) with cRC','Real','Exist','Todo
Todo=strip(Todo,'L','/')         /* strip leading /, can become null */

/* verify/correct access rights for existing part of the path */
if cRC == 0
then do
  if Dir == ''
    then Done=''              /* verify Root when only Root provided */
    else Done=Root   /* skip verifying Root when Root & Dir provided */
  cRC=max(cRC,_setPathAccess(Exist,Done))
end    /* _existPath() success */

/* create missing directories */
if cRC == 0
then do while Todo <> ''
  parse var Todo Dir '/' Todo             /* cut off first directory */

  if _syscall('mkdir' Exist'/'Dir DefaultMask)
  then do
    Exist=Exist'/'Dir
    say '-- created' Exist DefaultMask
    call _addReport 'mkdir',Exist DefaultMask
  end    /* */
  else do
    cRC=8                          /* syscall already reported error */
    leave                                              /* LEAVE LOOP */
  end    /* */
end    /* while Todo */

/* update permission bits of final directory if requested */
if (cRC == 0) & (pBits <> '') & (pBits <> DefaultMask)
  then cRC=max(cRC, ,
          _setPathAccess(Exist,left(Exist,lastpos('/',Exist)-1),pBits))

if Debug then say '< _mkdir' cRC
return cRC    /* _mkdir */

/*---------------------------------------------------------------------
 * --- Mount a file system
 * Returns return code
 * Updates Report.
 * Args:
 *  Path: mount point (must exist)
 *  Dsn : dsn of file system to mount
 *  Grow: (optional) '' or AGGRGROW
 */
_mount: PROCEDURE EXPOSE Debug Report.
parse arg Path,Dsn,Grow
if Debug then say '> _mount' Path','Dsn','Grow
cRC=0                                              /* assume success */

/* safety net, none of these should trigger */
if Path == ''
then do
  say '** ERROR (_mount) null string provided as path'
  cRC=12
end    /* */
else do
  /* get existing part of Path */
  parse value _existPath(Path) with xRC','RealDir','Dir','Todo

  if Todo <> ''   /* no need to test xRC, Todo has data when xRC > 0 */
  then do                   /* partial path does not count for mount */
    say '** ERROR (_mount) "'Path'"does not exist: "'Dir'"-"'Todo'"'
    cRC=12
  end    /* */
end    /* path provided */

if cRC == 0
then do
  /* get list of mounted file systems */
  if \_syscall('getmntent mnte.')
  then do
    say '** ERROR unable to get list of mounted file systems'
    cRC=8
  end    /* */
  else do
    Continue=1
    if Debug then say '.' mnte.0 'file systems mounted'
    /* mount point or file system already in use ? */
    do T=1 to mnte.0
      if (RealDir = mnte.7.T)                         /* 7=MNTE_PATH */
      then if (Dsn = mnte.6.T)                      /* 6=MNTE_FSNAME */
        then do  /* dsn already mounted on path */
          say '** INFO' strip(mnte.6.T) 'already mounted on' mnte.7.T
          call _addReport 'mount',mnte.7.T mnte.6.T
          Continue=0
          /* do not change cRC */
        end    /* */
        else do  /* other dsn mounted on path */
          say '** ERROR' strip(mnte.6.T) 'already mounted on' mnte.7.T
          Continue=0
          cRC=8
        end    /* */
      else if (Dsn = mnte.6.T)
        then do  /* dsn mounted on other path */
          say '** ERROR' strip(mnte.6.T) 'already mounted on' mnte.7.T
          Continue=0
          cRC=8
        end    /* */
    end    /* loop T */

    if Continue
    then do
      /* mount file system */
      mnte.=''                   /* initialize all stem fields to '' */
      mnte.2=0                      /* 0=MNT_MODE_RDWR 2=MNTE_MODE   */
      mnte.5='ZFS'                                 /*  5=MNTE_FSTYPE */
      mnte.6=Dsn                                   /*  6=MNTE_FSNAME */
      mnte.7=Path                                  /*  7=MNTE_PATH   */
      mnte.13=Grow                                 /* 13=MNTE_PARM   */

      if _syscall('mount mnte.')
      then do
        say '-- mounted' Dsn 'on' Path
        call _addReport 'mount',Path Dsn
      end    /* */
      else do /* syscall already reported error details, adding info */
        say 'MODE  :' mnte.2
        say 'FSTYPE:' mnte.5
        say 'FSNAME:' mnte.6
        say 'PATH  :' mnte.7
        say 'PARM  :' mnte.13
        say '** ERROR not able to mount file system'
        cRC=8
      end    /* mount */
    end    /* mount point & dsn free */
  end    /* getmntent */
end    /* Path exists */

/* check/set file system permission bits after mount */
if cRC <= 4
  then cRC=max(cRC, ,
                _setPathAccess(Path,left(Path,lastpos('/',Path)-1),,0))

if Debug then say '< _mount' cRC
return cRC    /* _mount */

/*---------------------------------------------------------------------
 * --- Show mount information for Path
 * Returns return code
 * Updates Report.
 * Args:
 *  Path: path to examine (must exist)
 */
_mountInfo: PROCEDURE EXPOSE Debug Report.
parse arg Path
parse value Path '/' with Path .                /* default: Path='/' */
if Debug then say '> _mountInfo' Path
cRC=0                                              /* assume success */

/* get device number of file system holding path */
if \_syscall('stat' Path 'st.')
then do
  say '** ERROR unable to get data of path "'Path'"'
  cRC=8
end    /* */
DevNo=x2d(st.4)                                          /* 4=ST_DEV */

/* get device information */
if cRC <= 4
then do
  if \_syscall('getmntent mnte.' DevNo)
  then do
    say '** ERROR unable to get data of file system' DevNo '('Path')'
    cRC=8
  end    /* */
end    /* */

/* get file system name, mountpoint, and mount mode of device */
if cRC <= 4
then do
  /* mnte. is a 2 dimensional array, with only 1 column -> mnte.*.1) */
  Dsn=strip(mnte.6.1)                               /* 6=MNTE_FSNAME */
  Root=strip(mnte.7.1)                                /* 7=MNTE_PATH */
  Mode=mnte.2.1                                       /* 2=MNTE_MODE */
                           /* bit 0 in MNTE_MODE indicates READ/RDWR */
  if right(x2b(d2x(Mode)),1)                            /* bit set ? */
    then Mode='READ'                            /* 1=MNT_MODE_RDONLY */
    else Mode='RDWR'                            /* 0=MNT_MODE_RDWR   */

  say '-- using file system' Dsn 'mounted in' Mode 'mode on' Root
  call _addReport 'mount',Root Dsn '('Mode')'
end    /* */

if Debug then say '< _mountInfo' cRC
return cRC    /* _mountInfo */

/*---------------------------------------------------------------------
 * --- Process DD ROOT
 * Returns return code
 * Updates Root (no trailing /, can be '')
 * Args:
 *  DD: DD name to process
 */
_rootDD: PROCEDURE EXPOSE Debug ExecEnv Root
parse upper arg DD
if Debug then say '> _rootDD' DD
cRC=0                                              /* assume success */
Root=''                                                   /* no data */

/* get input */
if \_ddExist(DD)
then do
  say '** ERROR unable to locate DD' DD
  cRC=12                   /* do not exit yet, show all errors first */
end    /* */
else if \_ddRead(DD)    /* _ddRead() already reported possible error */
  then cRC=12              /* do not exit yet, show all errors first */
  else do T=1 to Line.0         /* stem Line. populated by _ddRead() */
    Root=Root || strip(Line.T) /* convert multi-line input to 1 word */
  end    /* loop T */

/* validate input */
if pos(' ',Root) > 0
then do
  say '** ERROR path "'Root'" contains blanks'
  cRC=12                   /* do not exit yet, show all errors first */
end    /* */

if (left(Root,1) <> '/') & (cRC <= 4)
then do
  say '** ERROR path "'Root'" is not absolute (does not start with /)'
  cRC=12                   /* do not exit yet, show all errors first */
end    /* */

Root=strip(Root,'T','/')        /* strip trailing /, can become null */

say '-- will create root "'Root'"'
if Debug then say '< _rootDD' cRC
return cRC    /* _rootDD */

/*---------------------------------------------------------------------
 * --- Process DD DIRS
 * Returns return code
 * Updates Dirs.
 * Args:
 *  DD: DD name to process
 */
_dirsDD: PROCEDURE EXPOSE Debug ExecEnv Dirs.
parse upper arg DD
if Debug then say '> _dirsDD'
cRC=0                                              /* assume success */
Dirs.0=0                                                  /* no data */

/* get input */
if \_ddExist(DD)
then do
  say '** ERROR unable to locate DD' DD
  cRC=12                   /* do not exit yet, show all errors first */
end    /* */
else if \_ddRead(DD)    /* _ddRead() already reported possible error */
  then cRC=12              /* do not exit yet, show all errors first */

/* validate input */
S=0
do T=1 to Line.0                /* stem Line. populated by _ddRead() */
  Line.T=strip(Line.T)
  if left(Line.T,1) == '#' then iterate         /* skip comment line */
  Count=words(Line.T)

  select
  when Count <= 1 then nop                 /* null or only directory */
  when Count >  2  then do        /* more than 2 words is never good */
    say '** ERROR DD' DD', line' T', path "'Line.T'" contains blanks'
    cRC=12                 /* do not exit yet, show all errors first */
  end    /* */
  otherwise       /* 2 words, second word can be permission bit mask */
    if length(space(translate(word(Line.T,2),' ','01234567'),0)) > 0
    then do                      /* last word is NOT permission bits */
      say '** ERROR DD' DD', line' T', path "'Line.T'" contains blanks'
      cRC=12               /* do not exit yet, show all errors first */
    end    /* */
  end    /* select */

  /* only keep useful paths */
  Line.T=strip(Line.T,'L','/')   /* strip leading /, can become null */
  if Line.T <> ''
  then do
    S=S+1
    Dirs.S=Line.T
  end    /* */
end    /* loop T */
Dirs.0=S

if Dirs.0 > 0 then say '-- will create' Dirs.0 'sub-directory path(s)'
if Debug then do T=0 to Dirs.0; say '. Dirs.'T'="'Dirs.T'"'; end
if Debug then say '< _dirsDD' cRC
return cRC    /* _dirsDD */

/*---------------------------------------------------------------------
 * --- Display script usage information
 * Returns nothing
 * Args: /
 */
_displayUsage: PROCEDURE EXPOSE Debug ExecName
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
 * --- set access rights for an existing path
 * Returns return code
 * Updates Report.
 * Args:
 *  Path  : path to verify/correct
 *  Done  : (optional) root part of path that is already tested
 *  pBits : (optional) desired permission bit mask, set read & search
 *          bits for all if not specified
 *  Report: (optional) set to 0 to disable reporting no change
 */
_setPathAccess: PROCEDURE EXPOSE Debug Report.
parse arg Path,Done,pBits,Report
if Debug then say '> _setPathAccess' Path','Done','pBits','Report
parse value Report '1' with Report .            /* default: Report=1 */
cRC=0                                              /* assume success */

Dirs=translate(Path,' ','/')         /* split Path in separate words */
DirCount=words(Dirs)                   /* count only once, use often */
Offset=words(translate(Done,' ','/'))      /* # of dirs already done */
if Debug then say '. loop from directory' Offset' (+1?) to' DirCount

ToTest=Done
/* Offset == 0 (Done=='') means we have to test '/' (root) as well */
/* otherwise start at directory after Done */
if Offset > 0 then Offset=Offset+1

/* loop through the path starting at directory after Done */
do T=Offset to DirCount
  /* grow the path to test */
  select
  when T == 0 then ToTest='/'
  when T == 1 then ToTest='/'word(Dirs,T)
  otherwise
    ToTest=Totest'/'word(Dirs,T)
  end    /* select */
  if Debug then say '.' T'/'DirCount ToTest

  /* test the path, and update if needed */
  if \_syscall('lstat' ToTest 'st.')
  then do
    say '** ERROR not able to verify permissions for "'ToTest'"'
    cRC=8
  end    /* */
  else do
    OldMode=st.2                                        /* 2=ST_MODE */
    if pBits == '' /* set read & search bits for each permission byte*/
      then NewMode=translate(OldMode,'55775577','01234567')
      else NewMode=pBits

    if OldMode <> NewMode
    then if \_syscall('chmod' ToTest NewMode)
      then do
        say '** ERROR not able to set permissions for "'ToTest'"'
        cRC=8
      end    /* */
      else do
        say '-- changed' ToTest 'from' OldMode 'to' NewMode
        call _addReport 'chmod',ToTest OldMode '->' NewMode
      end    /* */
    else do
      if Debug then say '. not changing' ToTest OldMode
      if Report then call _addReport 'keep',ToTest OldMode
    end    /* */
  end    /* lstat */
end    /* loop T */

if Debug then say '< _setPathAccess' cRC
return cRC    /* _setPathAccess */

/*---------------------------------------------------------------------
 * --- Find which part of Path already exists
 * Returns
 *  cRC    : return code
 *  RealDir: '' or Dir with symlinks resolved (no trailing /)
 *  Dir    : '' or existing part of Path (no trailing /)
 *  NoExist: '' or unresolved part of Path (including leading /)
 * Args:
 *  Path: path to examine
 */
_existPath: PROCEDURE EXPOSE Debug
parse arg Path
if Debug then say '> _existPath' Path
cRC=0                                              /* assume success */
Verbose=0                                 /* no syscall error report */
Dir=Path
NoExist=''

if Path == ''
then do
  say '** ERROR (_existPath) null string provided as path'
  cRC=12
end    /* */  /* keep taking off the last directory until Dir exists */
else do while Dir <> ''
  if Debug then say '.' Dir '-' NoExist

  if _syscall('realpath' Dir 'RealDir',Verbose)  /* resolve symlinks */
  then leave                                           /* LEAVE LOOP */
  else do       /* 'syscall realpath' fails if target does not exist */
    /* avoid infinite loop, 'realpath /' should have been successful */
    if Dir == '/'
    then do
      Dir=''
      leave                                            /* LEAVE LOOP */
    end    /* */
    NoExist=substr(Dir,lastpos('/',Dir)) || NoExist
    Dir=left(Dir,lastpos('/',Dir)-1)
    if Dir == '' then Dir='/'         /* test root, this should work */
  end    /* */
end    /* while Dir */

/*
 * No part of Path exists (Dir == '') and Path being absolute (starting
 * with /) indicates something is wrong, as at least system root (/)
 * should have existed. Rerun syscall without blocking error report.
 */
if (Dir == '') & (left(Path,1) == '/')
then do
  x=_syscall('realpath' Path 'x')              /* show error details */
  say '** ERROR not able to determine existing part of "'Path'"'
  cRC=8
end    /* */

if Dir == '/' then Dir=''                 /* undo earlier adjustment */
if Debug then say '. rc' cRC', resolved' RealDir', old' ,
  Dir', no match' NoExist
if Debug then say '< _existPath' cRC
return cRC','RealDir','Dir','NoExist    /* _existPath */

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
  say '** ERROR syscall command failed:' _Cmd
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
      say '** ERROR syscall command failed:' _Cmd
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
 * --- Convert boolean value to text
 * Returns FALSE or TRUE
 * Args:
 *  1: 0 or 1
 */
_boolean: /* NO PROCEDURE */
return word('FALSE TRUE',arg(1)+1)    /* _boolean */

/*---------------------------------------------------------------------
 * --- add arg(2) to Report.arg(1).x and increase Report.arg(1).0
 * Returns current value of Report.arg(1).x (which is 1)
 * Assumes Report. is primed to 1
 * Updates Report.
 * Args:
 *  1: name of report group
 *  2: text to add to report group
 *
 * Logic:
 * Value(variable[,new_value]) returns the current content of variable
 * and optionally assigns a new value.
 *
 * 4 - value(
 * 3 -       'Report.'arg(1)'.'
 * 2 -                         value('Report.'arg(1)'.0'
 * 1 -                                ,value('Report.'arg(1)'.0')+1
 *                                   )
 * 4 -       ,arg(2)
 *          )
 * assume value of counter ('Report.'arg(1)'.0') is 1
 * assume value of entry 1 ('Report.'arg(1)'.1') is 1
 * 1 - get current value of counter (1) and add 1 -> result=2
 * 2 - get current value of counter (1) and update counter with result
 *     of step 1 -> result=1, counter=2
 * 3 - build name of entry 'Report.'arg(1)'.'result_of_step_2
 *     -> 'Report.'arg(1)'.1'
 * 4 - get current value of entry referenced by step 3, and update
 *     entry with arg(2) -> result=1, entry=arg(2)
 */
_addReport: /* NO PROCEDURE */
return value('Report.'arg(1)'.'value('Report.'arg(1) ||,
  '.0',value('Report.'arg(1)'.0')+1), arg(2))    /* _addReport */

/*---------------------------------------------------------------------
 * --- Writes Report. data
 * Returns return code
 * Updates Report.
 * Args:
 *  DD   : DD name to write to
 *  Key  : identifier for which report to write (Report.key.*)
 *  Title: report title
 */
_report: PROCEDURE EXPOSE Debug Report.
parse arg DD,Key,Title
if Debug then say '> _report' DD','Key','Title
cRC=0                                              /* assume success */

/* leave trail when there is no data */
Count=value('Report.'Key'.0') /* remember, the counter is 1 too high */
if Count = 1
then do
  call _addReport Key,'Nothing to report'
  Count=Count+1                             /* keep Count 1 too high */
end   /* */

/* add trailing blank line to report */
call _addReport Key,' '  /* now Count is the correct number of lines */

/* write title */
queue Title
queue copies('=',length(Title))
cRC=max(cRC,_ddWrite(DD,2,''))

/* write report */
do T=1 to Count
  queue value('Report.'Key'.'T)
  if Debug then say '.' Key':' value('Report.'Key'.'T)
end    /* loop T */
cRC=max(cRC,_ddWrite(DD,Count,''))

if Debug then say '< _report' cRC
return cRC    /* _report */

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
_ddWrite: PROCEDURE EXPOSE Debug
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
  say '** ERROR writing DD' DD
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
 * Updates stem Line.
 * Args:
 *  DD: DD name to read
 *
 * EXECIO documentation in "TSO/E REXX Reference (SA22-7790)"
 */
_ddRead: PROCEDURE EXPOSE Debug Line.
parse upper arg DD
if Debug then say '> _ddRead' DD
cRC=0                                              /* assume success */
Line.0=0                                                  /* no data */

"EXECIO * DISKR" DD "(FINIS STEM Line."
if Debug then say '. execio Line.0='Line.0
/*do T=0 to Line.0; say '. Line.'T='Line.T; end */          /* trace */

Success=(rc == 0)
if \Success
then do
  Text.='Undocumented error code.'
  Text.4='An empty data set was found in the data set concatenation.'
  Text.20='Severe error.'
  say '** ERROR reading DD' DD
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
 * --- Test whether DSN exists or not
 * Returns boolean indicating DSN exists (1) or not (0)
 * Args:
 *  DSN: data set name to test
 *
 * listdsi documentation in "TSO/E REXX Reference (SA22-7790)"
 */
_dsnExist: PROCEDURE EXPOSE Debug SYSMSGLVL2
parse upper arg Dsn
if Debug then say '> _dsnExist' Dsn

cRC=listdsi("'"Dsn"'")
if Debug then say '. listdsi' DD 'RC' cRC 'RSN' SYSREASON
           /* sysout/sysin/dummy *//* not catlg'd */ /* tmp data set */
Exist=((cRC <=4) | (SYSREASON = 3) | (SYSREASON = 5) | (SYSREASON = 27))
if Debug & \Exist then say '.' SYSMSGLVL2

if Debug then say '< _dsnExist' _boolean(Exist)
return Exist    /* _dsnExist */

