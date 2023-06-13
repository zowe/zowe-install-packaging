/*
  This program and the accompanying materials are
  made available under the terms of the Eclipse Public License v2.0 which accompanies
  this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

class ConfigManager {
    constructor() {
        this.zowe = {
            workspaceDirectory: '.',
            externalDomains: []
        }
    }
    setTraceLevel(level) {
    }
    getTraceLevel() {
        return 0;
    }
    addConfig(name) {
        return 0;
    }
    setConfigPath(configName, configPath) {
        return 0;
    }
    loadSchemas(configName,schemaList) {
        return 0;
    }
    getConfigData(configName) {
        return {
            zowe: {
                workspaceDirectory: '.',
                externalDomains: []
            }
        }
    }
    setParmlibMemberName(configName,parmlibMemberName) {
        return 0;
    }
    loadConfiguration(configName) {
        return 0;
    }
    makeModifiedConfiguration(oldConfigName, newConfigName, updateObject, arrayMergeStrategy) {
        return 0;
    }
    validate(configName) {
        return {
            ok: true
        };
    }
    writeYAML(configName) {
        return [0, null];
    }
}

exports.ConfigManager = ConfigManager;
