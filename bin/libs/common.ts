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
import * as xplatform from 'xplatform';

import * as fs from './fs';
import * as shell from './shell';
import * as strftime from './strftime';
import * as bufferlib from './buffer';
declare namespace console {
  function log(...args:string[]): void;
};


// these are shell environments we want to enforce in all cases
std.setenv('_CEE_RUNOPTS', "FILETAG(AUTOCVT,AUTOTAG) POSIX(ON)");
std.setenv('_TAG_REDIR_IN', 'txt');
std.setenv('_TAG_REDIR_OUT', 'txt');
std.setenv('_TAG_REDIR_ERR', 'txt');
std.setenv('_BPXK_AUTOCVT', "ON");
std.setenv('_EDC_ADD_ERRNO2', '1'); //show details on error
std.unsetenv('ENV'); // just in case, as it can cause unexpected output

enum LOG_LEVEL {
  ERROR = 0,
  WARN,
  INFO,
  DEBUG,
  TRACE
};

function getLogLevel(name:string, defaultLevel:LOG_LEVEL):LOG_LEVEL {
    switch (name.toUpperCase()){
        case "ERROR": return LOG_LEVEL.ERROR;
        case "WARN": return LOG_LEVEL.WARN;
        case "INFO": return LOG_LEVEL.INFO;
        case "DEBUG": return LOG_LEVEL.DEBUG;
        case "TRACE": return LOG_LEVEL.TRACE;
        default: return defaultLevel;
    }
}


export function requireZoweYaml() {
  const configFiles = std.getenv('ZWE_CLI_PARAMETER_CONFIG');
  if (!configFiles) {
    printErrorAndExit(`Error ZWEL0108E: Zowe YAML config file is required.`);
  } else {
    //configmgr will consume this property and error out if it doesnt like it, or not, so just let it do the error-checking
  }
}

const BUFFER_SIZE=4096;
function readStreamFully(fd:number):string{
  let readBuffer = new Uint8Array(BUFFER_SIZE);
  let fileBuffer = new bufferlib.ExpandableBuffer(BUFFER_SIZE);
  
  let bytesRead = 0;
  do {
    bytesRead = os.read(fd, readBuffer.buffer, 0, BUFFER_SIZE);
    fileBuffer.append(readBuffer,0,bytesRead);
  } while (bytesRead == BUFFER_SIZE);
  // let hex = fileBuffer.dump(fileBuffer.pos);
  // console.log("out "+hex);
  let result = fileBuffer.getString();
  if (result.endsWith('\n')) {
    return result.substring(0,result.length-1);
  } else {
    return result;
  }
}

export function getUserId(): string|undefined {
  //moved from sys to simplify dependency
  let user = std.getenv('USER');
  if (!user) {
    user = std.getenv('USERNAME');
  }
  if (!user) {
    user = std.getenv('LOGNAME');
  }
  if (!user) {

    let pipeArray = os.pipe();
    if (!pipeArray){
      return user;
    }
    if (!std.getenv('PATH')) {
      std.setenv('PATH','/bin:.:/usr/bin');
    }
    const rc = os.exec(['whoami'], { block: true, usePath: true, stdout: pipeArray[1]});
    
    let out = readStreamFully(pipeArray[0]);
    os.close(pipeArray[0]);
    os.close(pipeArray[1]);

    if (!rc) {
      user=out;
      std.setenv('USER', user);
    }
  }
  return user;
}


export function date(...args: string[]): string|undefined {
  if (!args) {
    return strftime.strftime('%a %b %e %T %Z %Y');
  } else {
    let arg = args.length == 1 ? args[0] : args[args.length-1];
    if (arg.startsWith("'+")) {
      arg=arg.substring(2,arg.length-1);
    }
    return strftime.strftime(arg);
  }
}


let logExists = false;

function writeLog(message: string): boolean {
  const filename = std.getenv('ZWE_PRIVATE_LOG_FILE');
  if (filename) {
    logExists = logExists || fs.fileExists(filename);
    if (!logExists) {
      xplatform.storeFileUTF8(filename, xplatform.AUTO_DETECT, message);
      logExists = fs.fileExists(filename);
      if (logExists) {
        shell.execSync(`chmod`, `640`, filename);
      }
      return logExists;
    }
    else {
      return xplatform.appendFileUTF8(filename, xplatform.AUTO_DETECT, message) == 0;
    }
  }
  return false;
}


export function printRawMessage(message: string, isError: boolean, writeTo:string[]=['console','log']): boolean {
  if (writeTo.includes('console')) {
    if (isError) {
      //TODO this prints junk
      //std.err.printf(stringlib.asciiToEbcdic(message+'\n'));
      console.log('ERROR: '+message);
    } else if (std.getenv('ZWE_CLI_PARAMETER_SILENT') != 'true') {
      
      console.log(message);
    }
  }
  if (writeTo.includes('log')) {
    writeLog(message+'\n');
  }
  return true;
}

export function printMessage(message: string, writeTo?:string[]): boolean {
  return printRawMessage(message, false, writeTo);
}

// errors are written to STDERR
export function printError(message: string, writeTo?:string[]): boolean {
  return printRawMessage(message, true, writeTo);
}

export function printDebug(message: string, writeTo?:string[]): boolean {
  const level = std.getenv('ZWE_PRIVATE_LOG_LEVEL_ZWELS');
  if (level == 'DEBUG' || level == 'TRACE') {
    return printRawMessage(message, false, writeTo);
  }
  return false;
}

export function printTrace(message: string, writeTo?:string[]): boolean {
  const level = std.getenv('ZWE_PRIVATE_LOG_LEVEL_ZWELS');
  if (level == 'TRACE') {
    return printRawMessage(message, false, writeTo);
  }
  return false;
}

export function printErrorAndExit(message: string, writeTo:string[]=['console','log'], exitCode:number=1): void {
  printError(message, writeTo);
  std.exit(exitCode);
}

export function printEmptyLine(writeTo?:string[]): boolean {
  return printMessage("", writeTo);
}

export function printLevel0Message(message?: string, writeTo?:string[]): boolean {
  printMessage("===============================================================================", writeTo);
  if (message) {
    printMessage(`>> ${message.toUpperCase()}`, writeTo);
  }
  return printEmptyLine(writeTo);
}

export function printLevel1Message(message?: string, writeTo?:string[]): boolean {
  printMessage("-------------------------------------------------------------------------------", writeTo);
  if (message) {
    printMessage(`>> ${message}`, writeTo);
  }
  return printEmptyLine(writeTo);
}

export function printLevel2Message(message?: string, writeTo?:string[]): boolean {
  printEmptyLine(writeTo);
  if (message) {
    printMessage(`>> ${message}`, writeTo);
  }
  return printEmptyLine(writeTo);
}

export function printLevel0Debug(message?: string, writeTo?:string[]): boolean {
  printDebug("===============================================================================", writeTo);
  if (message) {
    printDebug(`>> ${message.toUpperCase()}`, writeTo);
  }
  return printDebug('', writeTo);
}

export function printLevel1Debug(message?: string, writeTo?:string[]): boolean {
  printDebug("-------------------------------------------------------------------------------", writeTo);
  if (message) {
    printDebug(`>> ${message}`, writeTo);
  }
  return printDebug('', writeTo);
}

export function printLevel2Debug(message?: string, writeTo?:string[]): boolean {
  printDebug('', writeTo);
  if (message) {
    printDebug(`>> ${message}`, writeTo);
  }
  return printDebug('', writeTo);
}

export function printLevel0Trace(message?: string, writeTo?:string[]): boolean {
  printTrace("===============================================================================", writeTo);
  if (message) {
    printTrace(`>> ${message.toUpperCase()}`, writeTo);
  }
  return printTrace('', writeTo);
}

export function printLevel1Trace(message?: string, writeTo?:string[]): boolean {
  printTrace("-------------------------------------------------------------------------------", writeTo);
  if (message) {
    printTrace(`>> ${message}`, writeTo);
  }
  return printTrace('', writeTo);
}

//TODO is message ever missing or should we just enforce it
export function printLevel2Trace(message?: string, writeTo?:string[]): boolean {
  printTrace('', writeTo);
  if (message) {
    printTrace(`>> ${message}`, writeTo);
  }
  return printTrace('', writeTo);
}


const FORMATTING_TEST = /^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/;
// runtime logging functions, follow zowe service logging standard
export function printFormattedMessage(service: string, logger: string, levelName: string, message: string): boolean {
  if (message == '-') {
    //TODO readmessage
    if (!message) {
      return false;
    }
  }

  const level:LOG_LEVEL = getLogLevel(levelName,LOG_LEVEL.INFO);
  const canonicalLevelName = LOG_LEVEL[level];
  const envLogValue = std.getenv(`ZWE_PRIVATE_LOG_LEVEL_${service}`);
  const expectedLogLevelVal:LOG_LEVEL = envLogValue ? getLogLevel(envLogValue,LOG_LEVEL.INFO) : LOG_LEVEL.INFO;
  let displayLog = expectedLogLevelVal >= level;
  if (!displayLog) {
    return false;
  }

  const logLinePrefix=`${date("-u", "'+%Y-%m-%d %T'")} <${service}:${xplatform.getpid()}> ${getUserId()} ${canonicalLevelName} (${logger})`;
  let lines = message.split('\n');
  lines.forEach((line: string)=> {
    if (!FORMATTING_TEST.test(line)) {
      line = `${logLinePrefix} ${line}`;
    }
    if (level == LOG_LEVEL.ERROR) {
      return printError(line, ['console']);
    }
    return printMessage(line, ['console']);
  });
  return true;
}

export function printFormattedTrace(service: string, logger: string, message: string): boolean {
  return printFormattedMessage(service, logger, "TRACE", message);
}

export function printFormattedDebug(service: string, logger: string, message: string): boolean {
  return printFormattedMessage(service, logger, "DEBUG", message);
}

export function printFormattedInfo(service: string, logger: string, message: string): boolean {
  return printFormattedMessage(service, logger, "INFO", message);
}

export function printFormattedWarn(service: string, logger: string, message: string): boolean {
  return printFormattedMessage(service, logger, "WARN", message);
}

export function printFormattedError(service: string, logger: string, message: string): boolean {
  return printFormattedMessage(service, logger, "ERROR", message);
}


let runtimeManifest:any;
export function getZoweRuntimeManifest(): any|undefined {
  if (!runtimeManifest) {
    const manifestFileName = `${std.getenv('ZWE_zowe_runtimeDirectory')}/manifest.json`;
    const result = xplatform.loadFileUTF8(manifestFileName,xplatform.AUTO_DETECT);
    if (result){
      printError('Could not read runtime manifest in '+manifestFileName);
    } else {
      runtimeManifest=JSON.parse(result);
    }
  }
  return runtimeManifest;
}

export function getZoweVersion(): string|undefined {
  if (!std.getenv('ZWE_VERSION')) {
    let manifest = getZoweRuntimeManifest();
    if (manifest) {
      std.setenv('ZWE_VERSION', manifest.version);
    }
  }
  return std.getenv('ZWE_VERSION');
}

function paddingLeft(str: string, pad: string): string {
  return str.split('\n')
    .map(function(line:string) {
      return pad+line;})
    .join('\n');
}
/*for use with shell.ts results, particularly where error is in out attribute*/
export function printShellResult(result: {rc: number, out?: string}, commandName: string  = 'command'): void {
  if (result.rc == 0) {
    printDebug(`  * ${commandName} succeeded`);
    printTrace(`  * Exit code: ${result.rc}`);
    printTrace(`  * Output:`);
    if (result.out) {
      printTrace(paddingLeft(result.out, "    "));
    }
  } else {
    printDebug(`  * ${commandName} failed`);
    printError(`  * Exit code: ${result.rc}`);
    printError(`  * Output:`);
    if (result.out) {
      printError(paddingLeft(result.out, "    "));
    }
  }
}

/*for use with shell.ts results, particularly where error is in out attribute*/
export function printShellResultIfError(result: {rc: number, out?: string}, commandName: string  = 'command'): void {
  if (result.rc != 0) {
    printDebug(`  * ${commandName} failed`);
    printError(`  * Exit code: ${result.rc}`);
    printError(`  * Output:`);
    if (result.out) {
      printError(paddingLeft(result.out, "    "));
    }
  }
}




//From 'index.sh'
std.setenv('ZWE_PRIVATE_DS_SZWESAMP', 'SZWESAMP');
std.setenv('ZWE_PRIVATE_DS_SZWEEXEC', 'SZWEEXEC');
std.setenv('ZWE_PRIVATE_DEFAULT_ADMIN_GROUP', 'ZWEADMIN');
std.setenv('ZWE_PRIVATE_DEFAULT_ZOWE_USER', 'ZWESVUSR');
std.setenv('ZWE_PRIVATE_DEFAULT_ZIS_USER', 'ZWESIUSR');
std.setenv('ZWE_PRIVATE_DEFAULT_ZOWE_STC', 'ZWESLSTC');
std.setenv('ZWE_PRIVATE_DEFAULT_ZIS_STC', 'ZWESISTC');
std.setenv('ZWE_PRIVATE_DEFAULT_AUX_STC', 'ZWESASTC');
std.setenv('ZWE_PRIVATE_CORE_COMPONENTS_REQUIRE_JAVA', 'gateway,cloud-gateway,discovery,api-catalog,caching-service,metrics-service,files-api,jobs-api');

std.setenv('ZWE_PRIVATE_CLI_LIBRARY_LOADED', 'true');
