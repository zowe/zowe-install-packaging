
export type ZStat = {
    dev: number;
    ino: number;
    uid: number;
    gid: number;
    atime: number;
    mtime: number;
    ctime: number;
    extattrs: number;
    isText: boolean;
    ccsid: number;
};

export function changeTag(path:string, ccsid:number):number;
export function changeExtAttr(path: string, extattr:number, onOff:boolean):number;
export function zstat(path:string):[ZStat, number];
export var EXTATTR_SHARELIB:number;
export var EXTATTR_PROGCTL:number;
