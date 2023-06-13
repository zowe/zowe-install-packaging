/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as os from 'cm_os';
import * as zos from 'zos';

import * as common from './common';
import * as shell from './shell';
import { PathAPI as pathoid } from './pathoid';

/* 
   Below are not found in os module, but can be used against os.stat mode return values. 
   They were pulled from a system header which I hope is portable on all platforms
*/
//const S_ISUID = 0x0800;
//const S_ISGID = 0x0400;
//const S_ISVTX = 0x0200;
/* User permissions, rwx */
//const S_IRUSR = 0x0100;
const S_IWUSR = 0x0080;
//const S_IXUSR = 0x0040;
//const S_IRWXU = 0x01C0;
/* group permissions, rwx */
//const S_IRGRP = 0x0020;
//const S_IWGRP = 0x0010;
//const S_IXGRP = 0x0008;
//const S_IRWXG = 0x0038;
/* other permissions, rwx */
//const S_IROTH = 0x0004;
//const S_IWOTH = 0x0002;
//const S_IXOTH = 0x0001;
//const S_IRWXO = 0x0007;

const ENOTDIR = 135; //error for not a directory

export function resolvePath(...parts:string[]): string {
  let separator=os.platform == 'win32' ? '\\' : '/';
//  let badSeparator = os.platform == 'win32' ? '/' : '\\';
  let path='';
  parts.forEach((part:string)=> {
//    part=part.replaceAll(badSeparator, separator);
    if (part.startsWith('"') && part.endsWith('"')) {
      part=part.substring(1,part.length-1);
    } else if (part.startsWith("'") && part.endsWith("'")) {
      part=part.substring(1,part.length-1);
    }
    
    if (part.startsWith(separator)) {
      part=part.substring(1);
    }
    if (part.endsWith(separator)) {
      part = part.substring(0,part.length-1);
    }
    path+=separator+part;
  });
  return path;
}

export function mkdirp(path:string, mode?: number): number {
  let paths: string[] = [];
  let parts = path.split('/');
  let currentPath = '';
  parts.forEach((part:string)=> {
    currentPath+='/'+part;
    if (currentPath.startsWith('//')) {
      currentPath = currentPath.substring(1);
    }
    paths.push(currentPath);
  });

  let firstMissingDir: number;
  for (let i = paths.length-1; i > -1; i--) {
    if (directoryExists(paths[i])) {
      firstMissingDir = i+1;
      break;
    }
  }

  common.printDebug('paths='+JSON.stringify(paths));
  if (firstMissingDir >= paths.length) { return 0; }
  common.printDebug('firstMissingDir='+paths[firstMissingDir]);

  for (let i = firstMissingDir; i < paths.length; i++) {
    let rc = os.mkdir(paths[i], mode ? mode : 0o777);
    if (rc && (rc!=(0-std.Error.EEXIST))) {
      return rc;
    }
  }
  return 0;
}

export function cp(from: string, to: string): void {
  shell.execSync('cp', `-r`, from, to);
}


export function cpr(from: string, to: string): void {
  shell.execSync('cp', `-r`, from, to);
}

export function rmrf(path: string): number {
  const result = shell.execSync('rm', `-rf`, path);
  return result.rc;
}

export function appendToFile(path:string, content:string):void {
  //TODO
  throw 'Implement me!';  
}

export function createFile(path: string, mode: number, content?: string): boolean {
  let errObj = {errno:undefined};
  const file:std.File|null = std.open(path, 'w', errObj);
  if (errObj.errno) {
    common.printError(`File create failed for ${path}, error=${errObj.errno}`);
    return false;
  } else if (file == null){
    common.printError(`File create failed for ${path} unexpectedly`);
    return false;       
  }
/*  
  if (content) {
    let offset = 0;

    const buff = true ? stringlib.stringTo1047Buffer(content) : stringlib.stringToBuffer(content);
    
    os.write(fd, buff.buffer, offset, buff.byteLength);
  }
*/
  if (content) {
    file.puts(content);
  }
  file.close();
  return true;
}

export function createFileFromBuffer(path: string, mode: number, buff?: Uint8Array) {
  let errObj = {errno:undefined};
  const file = std.open(path, 'w', errObj);
  if (errObj.errno) {
    common.printError(`File create failed for ${path}, error=${errObj.errno}`);
    return false;
  } else if (file == null){
    common.printError(`File create failed for ${path} unexpectedly`);
    return false;       
  }
/*  
  if (content) {
    let offset = 0;

    const buff = true ? stringlib.stringTo1047Buffer(content) : stringlib.stringToBuffer(content);
    
    os.write(fd, buff.buffer, offset, buff.byteLength);
  }
*/
  if (buff) {
    file.write(buff.buffer, 0, buff.byteLength);
  }
  file.close();
  return true;
}

export function getFilesInDirectory(path: string): string[]|undefined {
  let returnArray = os.readdir(path);
  let files:string[] = [];
  if (!returnArray[1]) { //no error
    returnArray[0].forEach((file:string)=> {
      if (fileExists(pathoid.join(path, file))) {
        files.push(file);
      }
    });
    return files;
  } else {
    common.printError(`getFilesInDirectory path=${path}, err=`+returnArray[1]);
    return undefined;
  }  
}

export function getSubdirectories(path: string): string[]|undefined {
  let returnArray = os.readdir(path);
  let subdirs:string[] = [];
  if (!returnArray[1]) { //no error
    returnArray[0].forEach((dir:string)=> {
      if (directoryExists(pathoid.join(path,dir))) {
        subdirs.push(dir);
      }
    });
    return subdirs;
  } else {
    common.printError(`getSubdirectories path=${path}, err=`+returnArray[1]);
    return undefined;
  }  
}

export function directoryExists(path: string, silenceNotFound?: boolean): boolean {
  let returnArray = os.stat(path);
  if (!returnArray[1]) { //no error
    return ((returnArray[0].mode & os.S_IFMT) == os.S_IFDIR)
  } else {
    if ((returnArray[1] != std.Error.ENOENT) && !silenceNotFound) {
      common.printError(`directoryExists path=${path}, err=`+returnArray[1]);
    }
    return false;
  }
}

export function fileExists(path: string, silenceNotFound?: boolean): boolean {
  let returnArray = os.stat(path);
  if (!returnArray[1]) { //no error
    return ((returnArray[0].mode & os.S_IFMT) == os.S_IFREG)
  } else {
    if ((returnArray[1] != std.Error.ENOENT) && !silenceNotFound) {
      common.printError(`fileExists path=${path}, err=${returnArray[1]}`);
    }
    return false;
  }
}

export function pathExists(path: string): boolean {
  let returnArray = os.stat(path);
  if (!returnArray[1]) { //no error
    return true;
  } else {
    return returnArray[1] != std.Error.ENOENT;
  }

}

export function pathHasPermissions(path: string, mode: number): boolean {
  let returnArray = os.stat(path);
  if (!returnArray[1]) { //no error
    return (returnArray[0].mode & mode) === mode;
  } else {
    return false;
  }
}

export function convertToAbsolutePath(path: string): string|undefined {
  const result = os.realpath(path);
  if (!result[1]) {
    return result[0];
  } else {
    common.printError(`Could not convert ${path} to absolute path, err=${result[1]}`);
  }
  return undefined;
}

export function getTmpDir(): string {
  let tmp = '';
  common.printDebug(`  > Check if either TMPDIR or TMP points to writable directory, else try '/tmp' directory`);
  for (const dir of [std.getenv('TMPDIR'), std.getenv('TMP'), '/tmp']) {
    if (dir) {
      if (isDirectoryAccessible(dir)) {
        tmp = dir;
        break;
      } else {
        common.printErrorAndExit(`Error ZWEL0110E: Doesn't have write permission on ${dir} directory.`, undefined, 110);
      }
    }
  }
  return tmp;
}

/*
  NOTE: Contrary to function name, this does not create a temp file. It just checks if it exists (safe to create)
*/
export function createTmpFile(prefix: string = 'zwe', tmpdir?: string): string|undefined {
  if (!tmpdir) {
    tmpdir = getTmpDir();
  }
  common.printTrace(`  > create_tmp_file on ${tmpdir}`);
  while (true) {
    let file = `${tmpdir}/${prefix}-${Math.floor(Math.random()*10000)}`;
    common.printTrace(`    - test ${file}`);
    if (!pathExists(file)) {
      common.printTrace(`    - good`);
      return file;
    }
  }
}

export function isFileAccessible(file: string): boolean {
  return fileExists(file);
}

export function isDirectoryAccessible(directory: string): boolean {
  return directoryExists(directory);
}

export function countMissingDirectories(directories: string[]): number {
  let missing = 0;
  for (let i = 0; i < directories.length; i++) {
    if (!directoryExists(directories[i])) {
      missing++;
    }
  }
  return missing;
}

/*
  NOTE: Original shell function did a file existence check, not a dir existence check. Fixed a bug? Causing a bug?
*/
export function areDirectoriesAccessible(directories: string): number {
  return countMissingDirectories(directories.split(','));
}

export function isDirectoryWritable(directory: string): boolean {
  return pathHasPermissions(directory, os.S_IFDIR | S_IWUSR);
}

export function isFileWritable(file: string): boolean {
  return pathHasPermissions(file, os.S_IFREG | S_IWUSR);
}

export function areDirectoriesSame(dir1: string, dir2: string): boolean {
  let abs1 = convertToAbsolutePath(dir1);
  let abs2 = convertToAbsolutePath(dir2);
  return (abs1 === abs2) && abs1 !== undefined;
}
