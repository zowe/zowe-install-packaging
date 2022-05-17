
export function fileCopy(source:string, destination:string):[number,number,number];
export function fileCopyConverted(source:string, sourceCCSID:number,
                                  destination:string, destinationCCSID:number):[number,number,number];
export function dirname(path:string):[string,number];

export function getpid():number;

/**
   sourceCCSID == -1, means apply default charset conversion if necessary.

   sourceCCSID == 0, mean don't translate bytes, trust that they are UTF8, even if they aren't!
*/
export function stringFromBytes(data:ArrayBuffer, offset:number, length:number, sourceCCSID:number):string;

/**
   sourceCCSID as above
*/
export function loadFileUTF8(path:string, sourceCCSID:number):string;

export var AUTO_DETECT:number;
export var NO_CONVERT:number;
