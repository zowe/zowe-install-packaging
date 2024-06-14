/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as os from 'cm_os';
import * as xplatform from 'xplatform';

declare namespace console {
  function log(...args:string[]): void;
};

export class PathObject {
    
}

const isWindows:boolean = os.platform == "win32";
const winDriveRoot = /^[A-Za-z]\:\\/;

export class PathAPI {
    static sep: string;
    static delimiter: string;

    static pathRoot(path:string):string|null{
        if (isWindows){
            if (path.startsWith("\\\\")){ // UNC network path
                return path.substring(0,2);
            } else if (path.startsWith("\\")){ // root of current drive (ugh!)
                return path.substring(0,1);
            } else {
                let match = winDriveRoot.exec(path);
                if (match){
                    return match[0];
                } else {
                    return null;
                }
            }
        } else {
            if ((path.length > 0) && (path.charAt(0) == "/")){
                return "/";
            } else {
                return null;
            }
        }
    }
    
    static resolveDots(path:string):string {
        let root:string|null = PathAPI.pathRoot(path);
        let isRooted:boolean = (root != null) && (root.length > 0);
        let sep = isWindows ? "\\" : "/";
        let unrooted = (root && isRooted) ? path.substring(root.length) : path;
        let tokens = unrooted.split(sep);
        /* 
           console.log("root = "+root);
           console.log("tokens.length="+tokens.length);
        */
        let result = [];
        let upCount = 0;
        for (let i=tokens.length-1; i>=0; i--){
            let token = tokens[i];
            //console.log("token '"+token+"'");
            if (token == "."){
                // do nothing
            } else if (token == ".."){
                upCount++;
            } else {
                if (upCount > 0){
                    upCount--;
                } else {
                    result.push(token);
                }
            }
        }
        /* 
           console.log("backwards "+result);
        */
        if (isRooted){
            let rootedPath = result.reverse().join(sep);
            return root+rootedPath;
        } else {
            for (let u=0; u<upCount; u++){
                result.push("..");
            }
            return result.reverse().join(sep);
        }
    }


    static resolve(...pathSegments: string[]): string{
        let concatenatedPath:string = "";
        let segmentIsRoot = false;
        let [ currentDirectory, err ] = os.getcwd();
        let sep = isWindows ? "\\" : "/";

        if (err != 0){
            throw "current working directory not found with errno="+err;
        }

        for (let i = pathSegments.length - 1; i >= -1 && !segmentIsRoot; i--) {
            // here - short circuit
            let segment = (i >= 0 ? pathSegments[i]: currentDirectory);

            if (segment.length === 0) {
                continue;
            }

            concatenatedPath = segment + '/' + concatenatedPath;
            let segmentRoot = PathAPI.pathRoot(segment);
            segmentIsRoot = (segmentRoot != null) && (segmentRoot.length > 0);
        }
        
        let resolvedPath:string = this.resolveDots(concatenatedPath);
        
        if (resolvedPath.length > 0){
            return resolvedPath.endsWith(sep) && resolvedPath.length>1 ? resolvedPath.substring(0, resolvedPath.length-1) : resolvedPath;
        } else {
            return '.';
        }
    }
    
    static normalize(path: string): string{
        return PathAPI.resolveDots(path);
    }
    
    static isAbsolute(path: string): boolean {
        let root = PathAPI.pathRoot(path);
        return (root != null) && (root.length > 0);
    }
    
    static join(...paths: string[]): string{
        let sep = isWindows ? "\\" : "/";
        if (paths.length == 0){
            return ".";
        } 
        let normalized = PathAPI.resolveDots(paths.join(sep));
        if (normalized.length == 0){
            return "."; // per spec
        } else {
            return normalized;
        }
    }
    
    static relative(from: string, to: string): string{
        throw "Unimplemented";
    }
    
    static dirname(path: string): string{
        let [dir, err] = xplatform.dirname(path);
        if (err != 0){
            throw "dirname of '"+path+"' failed with err="+err;
        }
        return dir;
    }
    
    static basename(path: string, ext?: string): string{
      const sep = isWindows ? "\\" : "/";
      const index = path.lastIndexOf('/', path.endsWith(sep) ? path.length-2 : Infinity);
      path = path.substring(index+1);
      if (ext && path.endsWith(ext)) {
        path = path.substring(0, path.length - ext.length);
      }
      return path;
    }
    
    static extname(path: string): string{
        throw "Unimplemented";
    }
    
    static format(pathObject: Partial<PathObject>): string{
        throw "Unimplemented";
    }
    
    static parse(path: string): PathObject{
        throw "Unimplemented";
    }


}
