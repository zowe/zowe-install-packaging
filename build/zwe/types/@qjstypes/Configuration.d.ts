/*
  This program and the accompanying materials are
  made available under the terms of the Eclipse Public License v2.0 which accompanies
  this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

export interface ConfigManager {
    setTraceLevel(level:number):void;
    getTraceLevel():number;
    addConfig(name:string):number;
    setConfigPath(configName:string,configPath:string):number;
    loadSchemas(configName:string,schemaList:string):number;
    getConfigData(configName:string):any;
    setParmlibMemberName(configName:string,parmlibMemberName:string):number;
    loadConfiguration(configName:string):number;
    makeModifiedConfiguration(oldConfigName:string, newConfigName: string, updateObject: any, arrayMergeStrategy: number): number;
    validate(configName:string):any;  // should give this a type
    writeYAML(configName:string):[ number, string|null];  // 0 means status is good , string present if 0
}

declare var ConfigManager: {
    prototype: ConfigManager;
    new(): ConfigManager;
}
