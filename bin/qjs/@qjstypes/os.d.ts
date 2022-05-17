
export type path = string;

export function exec(a:string[], options?:any):number;

export var O_CREAT:number;
export var O_WRONLY:number;
export var O_RDONLY:number;
export var S_IFMT:number;
export var S_IFIFO:number;
export var S_IFCHR:number;
export var S_IFDIR:number;
export var S_IFBLK:number;
export var S_IFREG:number;
export var S_IFSOCK:number;
export var S_IFLNK:number;
export var S_IFGID:number;
export var S_IFUID:number;
export var ENOENT:number;

export function open(filename:string, flags:number, mode:number):number;
export function close(fd:number):number;
export function read(fd:number, buffer:ArrayBuffer, offset:number, length:number):number;
export function write(fd:number, buffer:ArrayBuffer, offset:number, length:number):number;

export function remove(filename: string):number;
export function rename(oldname: string, newname :string):number;

export function stat(path:string):[any,number];
export function lstat(path:string):[any,number];

export function kill(pid:number, signal:number):void;

export function readdir(path:string):[string[],number];
export function realpath(path:string):[string,number]
export function getcwd():[string,number];
export function chdir(path:string):number;
export function mkdir(path:string, mode?:number):number;
export function dup2(oldfd:number, newfd:number):void;
export function sleep(millis:number):void;
export function pipe():[number,number]|null;

export var platform:string;
