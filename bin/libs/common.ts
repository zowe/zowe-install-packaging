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

import * as nodelib from './node';
import * as fs from './fs';
import * as shell from './shell';
import { ConfigManager } from 'Configuration';

// these are shell environments we want to enforce in all cases
std.setenv('_CEE_RUNOPTS', "FILETAG(AUTOCVT,AUTOTAG) POSIX(ON)");
std.setenv('_TAG_REDIR_IN', 'txt');
std.setenv('_TAG_REDIR_OUT', 'txt');
std.setenv('_TAG_REDIR_ERR', 'txt');
std.setenv('_BPXK_AUTOCVT', "ON");
std.setenv('_EDC_ADD_ERRNO2', '1'); //show details on error
std.unsetenv('ENV'); // just in case, as it can cause unexpected output

export const CONFIG_MGR = new ConfigManager();
CONFIG_MGR.setTraceLevel(0);


enum LOG_LEVEL {
  ERROR = 0,
  WARN,
  INFO,
  DEBUG,
  TRACE
};

export function requireZoweYaml() {
  nodelib.requireNode();

  const configFiles = 'ZWE_CLI_PARAMETER_CONFIG';
  if (!configFiles) {
    printErrorAndExit(`Error ZWEL0108E: Zowe YAML config file is required.`);
  } else {
    configFiles.split(',').forEach(function(file: string) {
      //TODO parmlib
      if (!fs.fileExists(file)) {
        printErrorAndExit(`Error ZWEL0109E: The Zowe YAML config file ${file} does not exist.`, undefined, 109);
      }
    });
  }
}

export function date(args?: string): string|undefined {
  const result = shell.execOutSync('date', args);
  if (!result.rc) {
    return result.out;
  }
}

let logExists = false;
let logFd;

function writeLog(message: string): boolean {
  if (!logExists) {
    const filename = std.getenv('ZWE_PRIVATE_LOG_FILE');
    if (filename) {
      logExists = fs.fileExists(filename);
      if (!logExists) {
        fs.createFile(filename, 0o640, message);
      }
    }
  }
}


export function printRawMessage(message: string, isError: boolean, writeTo:string[]=['console','log']): boolean {
  if (writeTo.includes('console')) {
    if (isError) {
      std.err.printf(message+'\n');
    } else if (std.getenv('ZWE_CLI_PARAMETER_SILENT') != 'true') {
      std.out.printf(message+'\n');
    }
  }
  if (writeTo.includes('log')) {
    return writeLog(message+'\n');
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
}

export function printTrace(message: string, writeTo?:string[]): boolean {
  const level = std.getenv('ZWE_PRIVATE_LOG_LEVEL_ZWELS');
  if (level == 'TRACE') {
    return printRawMessage(message, false, writeTo);
  }
}

export function printErrorAndExit(message: string, writeTo:string[]=['console','log'], exitCode:number=1): boolean {
  return printError(message, writeTo);
  std.exit(exitCode);
}

export function printEmptyLine(writeTo?:string[]): boolean {
  return printMessage("", writeTo);
}

export function printLevel0Message(message: string, writeTo?:string[]): boolean {
  printMessage("===============================================================================", writeTo);
  if (message) {
    printMessage(`>> ${message.toUpperCase()}`, writeTo);
  }
  return printEmptyLine(writeTo);
}

export function printLevel1Message(message: string, writeTo?:string[]): boolean {
  printMessage("-------------------------------------------------------------------------------", writeTo);
  if (message) {
    printMessage(`>> ${message}`, writeTo);
  }
  return printEmptyLine(writeTo);
}

export function printLevel2Message(message: string, writeTo?:string[]): boolean {
  printEmptyLine(writeTo);
  if (message) {
    printMessage(`>> ${message}`, writeTo);
  }
  return printEmptyLine(writeTo);
}

export function printLevel0Debug(message: string, writeTo?:string[]): boolean {
  printDebug("===============================================================================", writeTo);
  if (message) {
    printDebug(`>> ${message.toUpperCase()}`, writeTo);
  }
  return printDebug('', writeTo);
}

export function printLevel1Debug(message: string, writeTo?:string[]): boolean {
  printDebug("-------------------------------------------------------------------------------", writeTo);
  if (message) {
    printDebug(`>> ${message}`, writeTo);
  }
  return printDebug('', writeTo);
}

export function printLevel2Debug(message: string, writeTo?:string[]): boolean {
  return printDebug('', writeTo);
  if (message) {
    printDebug(`>> ${message}`, writeTo);
  }
  return printDebug('', writeTo);
}

export function printLevel0Trace(message: string, writeTo?:string[]): boolean {
  printTrace("===============================================================================", writeTo);
  if (message) {
    printTrace(`>> ${message.toUpperCase()}`, writeTo);
  }
  return printTrace('', writeTo);
}

export function printLevel1Trace(message: string, writeTo?:string[]): boolean {
  printTrace("-------------------------------------------------------------------------------", writeTo);
  if (message) {
    printTrace(`>> ${message}`, writeTo);
  }
  return printTrace('', writeTo);
}

export function printLevel2Trace(message: string, writeTo?:string[]): boolean {
  printTrace('', writeTo);
  if (message) {
    printTrace(`>> ${message}`, writeTo);
  }
  return printTrace('', writeTo);
}


const FORMATTING_TEST = /^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/;
// runtime logging functions, follow zowe service logging standard
export function printFormattedMessage(service: string, logger: string, level: string, message: string): boolean {
  if (message == '-') {
    //TODO readmessage
    if (!message) {
      return false;
    }
  }

  const levelNum=LOG_LEVEL[level.toUpperCase()];

  let expectedLogLevelVal=LOG_LEVEL[getVarValue(`ZWE_PRIVATE_LOG_LEVEL_${service}`).toUpperCase() || 'INFO'];
  let displayLog = expectedLogLevelVal >= levelNum;
  if (!displayLog) {
    return false;
  }

  const logLinePrefix=`${date("-u '+%Y-%m-%d %T'")} <${service}:$$> ${getUserId()} ${level.toUpperCase()} (${logger})`;
  let lines = message.split('\n');
  lines.forEach((line: string)=> {
    if (!FORMATTING_TEST.test(line)) {
      line = `${logLinePrefix} ${line}`;
    }
    if (levelNum == LOG_LEVEL.ERROR) {
      return printError(line, ['console']);
    }
    return printMessage(line, ['console']);
  });
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
