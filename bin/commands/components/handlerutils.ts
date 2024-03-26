/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as common from '../../libs/common';
import * as configlib from '../../libs/config';
import * as shell from '../../libs/shell';
import * as objUtils from '../../utils/ObjUtils';

const ZOWE_CONFIG=configlib.getZoweConfig();

export class HandlerCaller {
  private handlerPath: string;
  constructor(private handler: string, private registry: string) {
    this.setEnvVars();
    this.handlerPath = ZOWE_CONFIG.zowe.extensionRegistry.handlers[handler].path;
  }

  setEnvVars(): void {
    std.setenv("ZWE_zowe_extensionDirectory", ZOWE_CONFIG.zowe.extensionDirectory);
    std.setenv('ZWE_CLI_PARAMETER_HANDLER',this.handler);
    std.setenv('ZWE_CLI_PARAMETER_REGISTRY',this.registry);
    const flattener = new objUtils.Flattener();

    flattener.setPrefix('ZWE_zowe_extensionRegistry_handlers_'+this.handler+"_");
    flattener.setSeparator('_');
    flattener.setKeepArrays(true);
    const flat = flattener.flatten(ZOWE_CONFIG.zowe.extensionRegistry.handlers[this.handler]);
    //give handler its zowe.yaml config section
    Object.keys(flat).forEach((env) => {
      std.setenv(env, flat[env]);
    });
    
  }

  public search(componentName: string): number {
    std.setenv('ZWE_CLI_REGISTRY_COMMAND', 'search');
    common.printMessage(`Calling handler '${this.handler}' to search for ${componentName}`);

    const result = shell.execSync('sh', '-c', `_CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${std.getenv('ZWE_zowe_runtimeDirectory')}/bin/utils/configmgr -script "${this.handlerPath}"`);
    common.printMessage(`Handler search exited with rc=${result.rc}`);
    return result.rc;
  }

  public uninstall(componentName: string, dryRun?: boolean): string {
    std.setenv('ZWE_CLI_REGISTRY_COMMAND', 'uninstall');
    common.printMessage(`Calling handler '${this.handler}' to remove ${componentName}`);
    
    //TODO some scripts use COMPONENT_NAME, others COMPONENT_FILE, COMPONENT_ID...simplify the API. I'm assigning COMPONENT_NAME for simplicity.
    std.setenv("ZWE_CLI_PARAMETER_COMPONENT_NAME", componentName);
    
    std.setenv('ZWE_CLI_REGISTRY_DRY_RUN', dryRun ? 'true' : 'false');

    const result = shell.execOutSync('sh', '-c', `_CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${std.getenv('ZWE_zowe_runtimeDirectory')}/bin/utils/configmgr -script "${this.handlerPath}"`);
    common.printMessage(`Handler uninstall exited with rc=${result.rc}`);

    if (result.rc) {
      common.printError(`Handler output follows`);
      common.printMessage(result.out);
      return 'null';
    } else {
      common.printDebug(result.out);
    }
    let output = result.out.split('\n').filter(line => line.startsWith('ZWE_CLI_PARAMETER_COMPONENT_NAME='));
    if (output[0]) {
      return output[0].substring('ZWE_CLI_PARAMETER_COMPONENT_NAME='.length);
    }
    return 'null';

  }

  public upgrade(component: string, dryRun?: boolean): string {
    return this.installOrUpgrade(component, 'upgrade', dryRun);
  }

  public install(component: string, dryRun?: boolean): string {
    return this.installOrUpgrade(component, 'install', dryRun);
  }

  private installOrUpgrade(component: string, action: string, dryRun?: boolean): string {
    std.setenv('ZWE_CLI_REGISTRY_COMMAND', action);
    common.printMessage(`Calling handler '${this.handler}' to ${action} ${component}`);
    
    //TODO some scripts use COMPONENT_NAME, others COMPONENT_FILE, COMPONENT_ID...simplify the API. I'm assigning COMPONENT_NAME for simplicity.
    std.setenv("ZWE_CLI_PARAMETER_COMPONENT_NAME", component);
    
    std.setenv('ZWE_CLI_REGISTRY_DRY_RUN', dryRun ? 'true' : 'false');


    const result = shell.execOutSync('sh', '-c', `_CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${std.getenv('ZWE_zowe_runtimeDirectory')}/bin/utils/configmgr -script "${this.handlerPath}"`);
    common.printMessage(`Handler ${action} exited with rc=${result.rc}`);

    if (result.rc) {
      common.printError(`Handler output follows`);
      common.printMessage(result.out);
      return 'null';
    } else {
      common.printDebug(result.out);
    }

    let output = result.out.split('\n').filter(line => line.startsWith('ZWE_CLI_PARAMETER_COMPONENT_FILE='));
    if (output[0]) {
      return output[0].substring('ZWE_CLI_PARAMETER_COMPONENT_FILE='.length);
    }
    return 'null';
  }

  
}

export function getHandler(handler?: string): string|undefined {
  if (!handler) {
    handler=ZOWE_CONFIG.zowe.extensionRegistry?.defaultHandler;
    if (!handler) {
      return undefined;
    }
  }
  return handler;
}

//registry required by validation, so if missing program exits before this.
export function getRegistry(handler: string, registry?: string) {
  if (!registry) {
    registry=ZOWE_CONFIG.zowe.extensionRegistry.handlers[handler].registry;
  }
  return registry;
}
