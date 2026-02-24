/*
  This program and the accompanying materials are
  made available under the terms of the Eclipse Public License v2.0 which accompanies
  this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

export type ZStat = {
    dev: number;
    ino: number;
    mode: number;
    nlink: number;
    uid: number;
    gid: number;
    rdev: number;
    size: number;
    blocks: number;
    atime: number;
    mtime: number;
    ctime: number;
    extattrs: number;
    isText: boolean;
    ccsid: number;
};

export type Statvfs = {
  bsize: number;
  blocks: number;
  bavail: number;
  fsid: number;
  flag: number;
  frsize: number;
  bfree: number;
  files: number;
  ffree: number;
  favail: number;
  namemax: number;
  OEmaxfilesizehw: number;
  OEmaxfilesizelw: number;
  OEusedspace: number;
  OEinvarsec: number;
}

export function getEsm(): string;
export function getZosVersion(): number;
export function changeTag(path:string, ccsid:number):number;
export function changeExtAttr(path: string, extattr:number, onOff:boolean):number;
export function zstat(path:string):[ZStat, number];
export function getStatvfs(path: string): [Statvfs, number];
export var EXTATTR_SHARELIB:number;
export var EXTATTR_PROGCTL:number;
