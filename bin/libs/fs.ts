/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'std';
import * as os from 'os';
import * as zos from 'zos';
import * as common from './common';
import * as stringlib from './string';
import * as shell from './shell';

/* 
   Below are not found in os module, but can be used against os.stat mode return values. 
   They were pulled from a system header which I hope is portable on all platforms
*/
const S_ISUID = 0x0800;
const S_ISGID = 0x0400;
const S_ISVTX = 0x0200;
/* User permissions, rwx */
const S_IRUSR = 0x0100;
const S_IWUSR = 0x0080;
const S_IXUSR = 0x0040;
const S_IRWXU = 0x01C0;
/* group permissions, rwx */
const S_IRGRP = 0x0020;
const S_IWGRP = 0x0010;
const S_IXGRP = 0x0008;
const S_IRWXG = 0x0038;
/* other permissions, rwx */
const S_IROTH = 0x0004;
const S_IWOTH = 0x0002;
const S_IXOTH = 0x0001;
const S_IRWXO = 0x0007;


export function mkdirp(path:string, mode?: number): number {
  const parts = path.split('/');
  let dir = '/';
  for (let i = 0; i < parts.length; i++) {
    dir+=parts[i]+'/';
    let rc = os.mkdir(dir, mode ? mode : 0o777);
    if (rc) {
      return rc;
    }
  }
  return 0;
}

export function cp(from: string, to: string): void {
  shell.execSync('cp', `-r "${from}" "${to}"`);
}


export function cpr(from: string, to: string): void {
  shell.execSync('cp', `-r "${from}" "${to}"`);
}

export function appendToFile(path, content) {

}

export function createFile(path: string, mode: number, content?: string): boolean {
  const fd = os.open(path, os.O_CREAT | os.O_WRONLY, mode);
  if (fd<0) {
    common.printError(`File create failed for ${path}, error=${fd}`);
    return false;
  }

  if (content) {
    let offset = 0;

    const buff = true ? stringlib.stringTo1047Buffer(content) : stringlib.stringToBuffer(content);
    
    os.write(fd, buff.buffer, offset, buff.byteLength);
  }

  os.close(fd);
  return true;
  
  console.log(`TODO: write ${path}`);
}

export function createFileFromBuffer(path: string, mode: number, buff?: Uint8Array) {
  const fd = os.open(path, os.O_CREAT | os.O_WRONLY, mode);
  if (fd<0) {
    common.printError(`File create failed for ${path}, error=${fd}`);
    return false;
  }

  if (buff) {
    let offset = 0;
    os.write(fd, buff.buffer, offset, buff.byteLength);
  }

  os.close(fd);
  return true;
  
  console.log(`TODO: write ${path}`);
}

export function getFilesInDirectory(path: string): string[]|undefined {
  let returnArray = os.readdir(path);
  let files = [];
  if (!returnArray[1]) { //no error
    returnArray[0].forEach((file:string)=> {
      if (fileExists(file)) {
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
  let subdirs = [];
  if (!returnArray[1]) { //no error
    returnArray[0].forEach((dir:string)=> {
      if (directoryExists(dir)) {
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
    return ((returnArray[0].mode & os.S_IFDIR) == os.S_IFDIR)
  } else {
    if ((returnArray[1] != std.ENOENT) && !silenceNotFound) {
      common.printError(`directoryExists path=${path}, err=`+returnArray[1]);
    }
    return false;
  }
}

export function fileExists(path: string, silenceNotFound?: boolean): boolean {
  let returnArray = os.stat(path);
  if (!returnArray[1]) { //no error
    return ((returnArray[0].mode & os.S_IFREG) == os.S_IFREG)
  } else {
    if ((returnArray[1] != std.ENOENT) && !silenceNotFound) {
      common.printError(`fileExists path=${path}, err=`,returnArray[1]);
    }
    return false;
  }
}

export function pathExists(path: string): boolean {
  let returnArray = os.stat(path);
  if (!returnArray[1]) { //no error
    return true;
  } else {
    return returnArray[1] != std.ENOENT;
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

export function convertToAbsolutePath(file: string): string|undefined {
  const result = os.realpath(file);
  if (!result[1]) {
    return result[0];
  } else {
    common.printError(`Could not convert ${file} to absolute path, err=${result[1]}`);
  }
}

export function getTmpDir(): string {
  let tmp = std.getenv('TMPDIR');
  if (!tmp) {
    tmp = std.getenv('TMP');
  }
  if (!tmp) {
    tmp = '/tmp';
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
    let file = `${tmpdir}/${prefix}-${std.getenv('random')}`;
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
