export interface ConfigManager {
    setTraceLevel(level:number):void;
    getTraceLevel():number;
    addConfig(name:string):number;
    setConfigPath(configName:string,configPath:string):number;
    loadSchemas(configName:string,schemaList:string):number;
    getConfigData(configName:string):any;
    loadConfiguration(configName:string):number;
    validate(configName:string):any;  // should give this a type
    writeYAML(configName:string):[ number, string|null];  // 0 means status is good , string present if 0
}

declare var ConfigManager: {
    prototype: ConfigManager;
    new(): ConfigManager;
}
