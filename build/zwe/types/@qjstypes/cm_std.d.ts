/*
  This program and the accompanying materials are
  made available under the terms of the Eclipse Public License v2.0 which accompanies
  this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

export function getenv(varName:string):string|undefined;

export function setenv(varName:string, value:string):void;

export function unsetenv(varName:string):void;

/**
   really key-value pairs, but no strong type for return yet 
*/
export function getenviron():any;

export function exit(status:number):void;

export function loadFile(filename:string):string|null; // returns a string, or NULL if IO error


export interface File {
    printf(formatString:string, ...args:any[]):void;
    puts(s:string):void;
    close():number;
    tell():number;
    eof():boolean;
    error():boolean;
    clearerr():void;
    read(buffer:ArrayBuffer, position:number, length:number):number;
    write(buffer:ArrayBuffer, position:number, length:number):number;
}

export function fdopen(fd:number, fopenMode:string, errorObj?:any):File|null;
export function open(command:string, fopenMode:string, errorObj?:any):File|null;
export function popen(command:string, fopenMode:string, errorObj?:any):File|null;

/* STDOUT convenience functions */
export function puts(s:string):void;
export function printf(formatString:string, ...args:any[]):void;

/* builds a new string */
export function sprintf(formatString:string, ...args:any[]):string;

export function parseExtJSON(s:string):any;

export var out:File;
export var err:File;
export var frog:File; // JOE "in" is a reserved word

export type ErrorEnumType = {
    EINVAL: number,
    EIO:number,
    EACCES:number,
    EEXIST:number,
    ENOSPC:number,
    ENOSYS:number,
    EBUSY:number,
    ENOENT:number,
    EPERM:number,
    EPIPE:number
};

export var Error:ErrorEnumType;

