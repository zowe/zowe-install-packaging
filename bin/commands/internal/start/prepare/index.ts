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
import * as zos from 'zos';
import * as xplatform from 'xplatform';

import * as fs from '../../../../libs/fs';
import * as common from '../../../../libs/common';
import * as stringlib from '../../../../libs/string';
import * as shell from '../../../../libs/shell';
import * as sys from '../../../../libs/sys';
import * as config from '../../../../libs/config';
import * as component from '../../../../libs/component';
import * as varlib from '../../../../libs/var';
import * as java from '../../../../libs/java';
import * as node from '../../../../libs/node';
import * as zosmf from '../../../../libs/zosmf';

//# This command prepares everything needed to start Zowe.
const cliParameterConfig = std.getenv('ZWE_CLI_PARAMETER_CONFIG');
const runInContainer = std.getenv('ZWE_RUN_IN_CONTAINER');
const containerComponentId = std.getenv('ZWE_PRIVATE_CONTAINER_COMPONENT_ID');
//const installedComponentsEnv=std.getenv('ZWE_INSTALLED_COMPONENTS');
//const installedComponents = installedComponentsEnv ? installedComponentsEnv.split(',') : null;

const zosmfHost = std.getenv('ZOSMF_HOST');
const zosmfPort = Number(std.getenv('ZOSMF_PORT'));


const user = std.getenv('USER');

const ZOWE_CONFIG=config.getZoweConfig();

// Extra preparations for running in container
// - link component runtime under zowe <runtime>/components
// - `commands.configureInstance` is deprecated in v2
function prepareRunningInContainer() {
  // gracefully shutdown all processes
  common.printFormattedDebug("ZWELS", "zwe-internal-start-prepare,prepare_running_in_container", "Register SIGTERM handler for graceful shutdown.");
  os.signal(os.SIGTERM, sys.gracefullyShutdown);

  // read ZWE_PRIVATE_CONTAINER_COMPONENT_ID from component manifest
  // /component is hardcoded path we asked for in conformance
  const manifest = component.getManifest('/component');
  if (!manifest) {
    std.exit(1); //TODO error code
  }
  let componentId = std.getenv('ZWE_PRIVATE_CONTAINER_COMPONENT_ID');
  if (componentId) {
    componentId = manifest.name;
    std.setenv('ZWE_PRIVATE_CONTAINER_COMPONENT_ID', componentId);
  }

  common.printFormattedTrace("ZWELS", "zwe-internal-start-prepare,prepare_running_in_container:", `Prepare <runtime>/components/${componentId} directory.`);
  if (fs.directoryExists(`${runtimeDirectory}/components/${componentId}`)) {
    shell.execSync('rm', `-rf`, `"${runtimeDirectory}/components/${componentId}"`);
  }
  os.symlink(`${runtimeDirectory}/components/${componentId}`, '/component');
}

// Prepare log directory
function prepareLogDirectory() {
  const logDir = std.getenv('ZWE_zowe_logDirectory');
  common.printMessage(`Going to create logdir=${logDir}`);
  if (logDir) {
    let mkdirErr = os.mkdir(logDir, 0o750);
    common.printMessage(`mkdir completed with rc=${mkdirErr}`);
    if (!fs.isDirectoryWritable(logDir)) {
      common.printFormattedError("ZWELS", "zwe-internal-start-prepare,prepare_log_directory", `ZWEL0141E: User $(get_user_id) does not have write permission on ${logDir}.`);
      std.exit(141);
    }
  } else {
      common.printMessage(`no logdir, exiting`);
      std.exit(141);
  }
}

// Prepare workspace directory
function prepareWorkspaceDirectory() {
  const zwePrivateWorkspaceEnvDir=`${workspaceDirectory}/.env`;
  std.setenv('ZWE_PRIVATE_WORKSPACE_ENV_DIR', zwePrivateWorkspaceEnvDir);
  const zweStaticDefinitionsDir=`${workspaceDirectory}/api-mediation/api-defs`;
  std.setenv('ZWE_STATIC_DEFINITIONS_DIR', zweStaticDefinitionsDir);
  const zweGatewaySharedLibs=`${workspaceDirectory}/gateway/sharedLibs/`;
  std.setenv('ZWE_GATEWAY_SHARED_LIBS', zweGatewaySharedLibs);
  const zweDiscoverySharedLibs=`${workspaceDirectory}/discovery/sharedLibs/`;
  std.setenv('ZWE_DISCOVERY_SHARED_LIBS', zweDiscoverySharedLibs);

  let rc = fs.mkdirp(workspaceDirectory, 0o770);
  if (rc != 0) {
    common.printFormattedError("ZWELS", "zwe-internal-start-prepare,prepare_workspace_directory", `WARNING: Failed to set permission of some existing files or directories in ${workspaceDirectory}:`);
    common.printFormattedError("ZWELS", "zwe-internal-start-prepare,prepare_workspace_directory" , ''+rc);
  }

  // Create apiml dirs
  fs.mkdirp(zweStaticDefinitionsDir, 0o770);
  fs.mkdirp(zweGatewaySharedLibs, 0o770);
  fs.mkdirp(zweDiscoverySharedLibs, 0o770);
  //ensure 770 in case directories already existed
  shell.execSync('chmod', `770`, workspaceDirectory, zweStaticDefinitionsDir, zweGatewaySharedLibs, zweDiscoverySharedLibs);

  shell.execSync('cp', `${runtimeDirectory}/manifest.json`, workspaceDirectory);

  fs.mkdirp(zwePrivateWorkspaceEnvDir, 0o700);

  const zweCliParameterHaInstance = std.getenv('ZWE_CLI_PARAMETER_HA_INSTANCE');
  common.printFormattedDebug("ZWELS", "zwe-internal-start-prepare,prepare_workspace_directory", `initialize .instance-${zweCliParameterHaInstance}.env(s)`);
  // TODO delete this or get this from configmgr instead.
  config.generateInstanceEnvFromYamlConfig(zweCliParameterHaInstance);
}

// Global validations
function globalValidate(enabledComponents:string[]): void {
  common.printFormattedInfo("ZWELS", "zwe-internal-start-prepare,global_validate", "process global validations ...");

  // validate_runtime_user
  if (user == "IZUSVR") {
    common.printFormattedWarn("ZWELS", "zwe-internal-start-prepare,global_validate", "ZWEL0302W: You are running the Zowe process under user id IZUSVR. This is not recommended and may impact your z/OS MF server negatively.");
  }

  // reset error counter
  let privateErrors = 0;
  std.setenv('ZWE_PRIVATE_ERRORS_FOUND','0');

  let writable = fs.isDirectoryWritable(workspaceDirectory);
  if (!writable) {
    privateErrors++;
    common.printFormattedError('ZWELS', "zwe-internal-start-prepare,global_validate", `Workspace directory ${workspaceDirectory} is not writable`);
  }

  if (runInContainer != 'true') {
    // only do these check when it's not running in container

    // currently node is always required
    let nodeOk = node.validateNodeHome();
    if (!nodeOk) {
      privateErrors++;
      common.printFormattedError('ZWELS', "zwe-internal-start-prepare,global_validate", `Could not validate node home`);
    }

    // validate java for some core components
    //TODO this should be a manifest parameter that you require java, not a hardcoded list. What if extensions require it?
    if (enabledComponents.includes('gateway') || enabledComponents.includes('cloud-gateway') || enabledComponents.includes('discovery') || enabledComponents.includes('api-catalog') || enabledComponents.includes('caching-service') || enabledComponents.includes('metrics-service') || enabledComponents.includes('files-api') || enabledComponents.includes('jobs-api')) {
      let javaOk = java.validateJavaHome();
      if (!javaOk) {
        privateErrors++;
        common.printFormattedError('ZWELS', "zwe-internal-start-prepare,global_validate", `Could not validate java home`);
      }
    }
  } else {
    if (!containerComponentId) {
      let isSet = varlib.isVariableSet("ZWE_PRIVATE_CONTAINER_COMPONENT_ID", "Cannot find name from the component image manifest file");
      if (!isSet) {
        privateErrors++;
        common.printFormattedError('ZWELS', "zwe-internal-start-prepare,global_validate", "Cannot find name from the component image manifest file");
      }
    }
  }

  // validate z/OSMF for some core components
  if (zosmfHost && zosmfPort) {
    if (enabledComponents.includes('discovery') || enabledComponents.includes('files-api') || enabledComponents.includes('jobs-api')) {
      let zosmfOk = zosmf.validateZosmfHostAndPort(zosmfHost, zosmfPort);
      if (!zosmfOk) {
        privateErrors++;
        common.printFormattedError('ZWELS', "zwe-internal-start-prepare,global_validate", "Zosmf validation failed");
      }
    } else if (std.getenv('ZWE_components_gateway_apiml_security_auth_provider') == "zosmf") {
      let zosmfOk = zosmf.validateZosmfAsAuthProvider(zosmfHost, zosmfPort, 'zosmf');
      if (!zosmfOk) {
        privateErrors++;
        common.printFormattedError('ZWELS', "zwe-internal-start-prepare,global_validate", "Zosmf validation failed");
      }
    }
  }
  
  std.setenv('ZWE_PRIVATE_ERRORS_FOUND',''+privateErrors);
  varlib.checkRuntimeValidationResult("zwe-internal-start-prepare,global_validate");

  common.printFormattedInfo("ZWELS", "zwe-internal-start-prepare,global_validate", "global validations are successful");
}




// Validate component properties if script exists
function validateComponents(enabledComponents:string[]): any {
  common.printFormattedInfo("ZWELS", "zwe-internal-start-prepare,validate_components", "process component validations ...");

  const componentEnvironments = {};
  
  // reset error counter
  let privateErrors = 0;
  std.setenv('ZWE_PRIVATE_ERRORS_FOUND','0');
  enabledComponents.forEach((componentId: string)=> {
    common.printFormattedTrace("ZWELS", "zwe-internal-start-prepare,validate_components", `- checking ${componentId}`);
    const componentDir = component.findComponentDirectory(componentId);
    common.printFormattedTrace("ZWELS", "zwe-internal-start-prepare,validate_components", `- in directory ${componentDir}`);
    if (componentDir) {
      const manifest = component.getManifest(componentDir);

      //I believe the env var to config here is already to the merged one, and that should be good for performance
      const configValid = component.validateConfigForComponent(componentId, manifest, componentDir, std.getenv('ZWE_CLI_PARAMETER_CONFIG'));
      if (!configValid) {
        privateErrors++;
      }

      // check validate script
      const validateScript = manifest.commands ? manifest.commands.validate : undefined;
      common.printFormattedTrace("ZWELS", "zwe-internal-start-prepare,validate_components", `- commands.validate is ${validateScript}`);
      if (validateScript) {
        let fullPath = `${componentDir}/${validateScript}`;
        if (fs.fileExists(fullPath)) {
          common.printFormattedDebug("ZWELS", "zwe-internal-start-prepare,validate_components", `- process ${componentId} validate command ...`);
          const prevErrors = privateErrors;
          privateErrors = 0;
          //TODO verify that this returns things that we want, currently it just uses setenv
          const envVars = config.loadEnvironmentVariables(componentId);
          componentEnvironments[manifest.name] = envVars;
          let result = shell.execSync('sh', '-c', `. ${runtimeDirectory}/bin/libs/configmgr-index.sh && cd ${componentDir} && . ${fullPath}`);
          privateErrors=prevErrors;
          if (result.rc) {
            privateErrors++;
            common.printFormattedError(`ZWELS`, "zwe-internal-start-prepare,validate_components", `Error: Component ${componentId} ended with nonzero rc=${result.rc}`);
          }
        } else {
          common.printFormattedError("ZWELS", "zwe-internal-start-prepare,validate_components", `Error ZWEL0172E: Component ${componentId} has commands.validate defined but the file is missing.`);
        }
      }

      // check platform dependencies
      if (os.platform != 'zos') {
        const zosDeps = manifest.dependencies ? manifest.dependencies.zos : undefined;
        if (zosDeps) {
          common.printFormattedWarn("ZWELS", "zwe-internal-start-prepare,validate_components", `- ${componentId} depends on z/OS service(s). This dependency may require additional setup, please refer to the component documentation`);
        }
      }
    }
  });
  
  std.setenv('ZWE_PRIVATE_ERRORS_FOUND', ''+privateErrors);
  varlib.checkRuntimeValidationResult("zwe-internal-start-prepare,validate_components");

  common.printFormattedDebug("ZWELS", "zwe-internal-start-prepare,validate_components", "component validations are successful");
  return componentEnvironments;
}


// Run setup/configure on components if script exists
function configureComponents(componentEnvironments?: any, enabledComponents?:string[]) {
  common.printFormattedInfo("ZWELS", "zwe-internal-start-prepare,configure_components", "process component configurations ...");

  const zwePrivateWorkspaceEnvDir = std.getenv('ZWE_PRIVATE_WORKSPACE_ENV_DIR');
  const zweCliParameterHaInstance = std.getenv('ZWE_CLI_PARAMETER_HA_INSTANCE');
  
  
  enabledComponents.forEach((componentId: string)=> {
    common.printFormattedTrace("ZWELS", "zwe-internal-start-prepare,configure_components", `- checking ${componentId}`);
    const componentDir = component.findComponentDirectory(componentId);
    common.printFormattedTrace("ZWELS", "zwe-internal-start-prepare,validate_components", `- in directory ${componentDir}`);
    if (componentDir) {
      const manifestPath = component.getManifestPath(componentDir);
      const manifest = component.getManifest(componentDir);

      // prepare component workspace
      const componentName=manifest.name;
      const privateWorkspaceEnvDir=`${zwePrivateWorkspaceEnvDir}/${componentName}`;
      fs.mkdirp(privateWorkspaceEnvDir, 0o700);

      // copy manifest to workspace
      shell.execSync('cp', manifestPath, `${privateWorkspaceEnvDir}/`);

      common.printFormattedDebug("ZWELS", "zwe-internal-start-prepare,configure_components", `- configure ${componentId}`);

      // check configure script
      // TODO if this is to force 1 component to configure before another, we should really just make a manifest declaration that 1 component needs to run before another. It's fine to run a simple dependency chain to determine order of execution without getting into the advanced realm of full blown package manager dependency management tier checks
      const preconfigureScript=manifest.commands ? manifest.commands.preConfigure : undefined;
      common.printFormattedTrace("ZWELS", "zwe-internal-start-prepare,configure_components", `- commands.preConfigure is ${preconfigureScript}`);
      let loadedEnvVars = false;
      if (preconfigureScript) {
        const preconfigurePath=`${componentDir}/${preconfigureScript}`;
        if (fs.fileExists(preconfigurePath)) {
          common.printFormattedDebug("ZWELS", "zwe-internal-start-prepare,configure_components", `* process ${componentId} pre-configure command ...`);
          // execute preconfigure step. preconfigure does NOT export env vars.
          if (componentEnvironments && componentEnvironments[componentName]) {
            config.applyEnviron(componentEnvironments[componentName]);
            loadedEnvVars = true;
          } else {
            config.loadEnvironmentVariables(componentId);
            loadedEnvVars = true;
          }
          const result = shell.execOutErrSync('sh', '-c', `. ${runtimeDirectory}/bin/libs/configmgr-index.sh && cd ${componentDir} && . ${preconfigurePath}`);
          common.printFormattedDebug("ZWELS", "zwe-internal-start-prepare,configure_components", result.rc ? result.err : result.out);
        } else {
          common.printFormattedError("ZWELS", "zwe-internal-start-prepare,configure_components", `Error ZWEL0172E: Component ${componentId} has commands.preConfigure defined but the file is missing.`);
        }
      }

      // default build-in behaviors
      // - apiml static definitions
      let success=component.processComponentApimlStaticDefinitions(componentDir);
      if (success) {
        common.printFormattedDebug("ZWELS", "zwe-internal-start-prepare,configure_components", `${componentName} processComponentApimlStaticDefinitions success`);
      } else {
        common.printFormattedError("ZWELS", "zwe-internal-start-prepare,configure_components", `${componentName} processComponentApimlStaticDefinitions failure`);
      }
      // - generic app framework plugin
      success=component.processComponentAppfwPlugin(componentDir);      
      if (success) {
        common.printFormattedDebug("ZWELS", "zwe-internal-start-prepare,configure_components", `${componentName} processComponentAppfwPlugin success`);
      } else {
        common.printFormattedError("ZWELS", "zwe-internal-start-prepare,configure_components", `${componentName} processComponentAppfwPlugin failure`);
      }
                                    
      // - gateway shared lib
      success=component.processComponentGatewaySharedLibs(componentDir);
      if (success) {
        common.printFormattedDebug("ZWELS", "zwe-internal-start-prepare,configure_components", `${componentName} processComponentGatewaySharedLibs success`);
      } else {
        common.printFormattedError("ZWELS", "zwe-internal-start-prepare,configure_components", `${componentName} processComponentGatewaySharedLibs failure`);
      }

      // - discovery shared lib
      success=component.processComponentDiscoverySharedLibs(componentDir);
      if (success) {
        common.printFormattedDebug("ZWELS", "zwe-internal-start-prepare,configure_components", `${componentName} processComponentDiscoverySharedLibs success`);
      } else {
        common.printFormattedError("ZWELS", "zwe-internal-start-prepare,configure_components", `${componentName} processComponentDiscoverySharedLibs failure`);
      }

      // check configure script
      const configureScript = manifest.commands ? manifest.commands.configure : undefined;
      common.printFormattedTrace("ZWELS", "zwe-internal-start-prepare,configure_components", `- commands.configure is ${configureScript}`);
      if (configureScript) {
        const fullPath = `${componentDir}/${configureScript}`;
        if (fs.fileExists(fullPath)) {
          common.printFormattedDebug("ZWELS", "zwe-internal-start-prepare,configure_components", `* process ${componentId} configure command ...`);
          if (!loadedEnvVars) {
            if (componentEnvironments && componentEnvironments[componentName]) {
              config.applyEnviron(componentEnvironments[componentName]);
            } else {
              config.loadEnvironmentVariables(componentId);
            }
          }
          // execute configure step and generate environment snapshot
          // NOTE: env var list is not updated because it should not have changed between preconfigure step and now
          const result = shell.execOutSync('sh', '-c', `. ${runtimeDirectory}/bin/libs/configmgr-index.sh && cd ${componentDir} && . ${fullPath} ; export rc=$? ; export -p`);

          common.printFormattedDebug("ZWELS", "zwe-internal-start-prepare,configure_components", `${componentName} configure ended with rc=${result.rc}`);
          
          if (result.rc==0) {
            const exportContent = varlib.getEnvironmentExports(result.out);
            if (exportContent) {
              const rc = xplatform.storeFileUTF8(`${zwePrivateWorkspaceEnvDir}/${componentName}/.${zweCliParameterHaInstance}.env`, xplatform.AUTO_DETECT, exportContent);
              if (!rc) {
                
              } else {
                // set permission for the component environment snapshot
                shell.execSync('chmod', `700`, `"${zwePrivateWorkspaceEnvDir}/${componentName}/.${zweCliParameterHaInstance}.env"`);
              }
            }
            const outLines = result.out.split('\n');
            common.printFormattedInfo("ZWELS", "zwe-internal-start-prepare,configure_components", `- commands.configure output from ${componentId} is:`);
            common.printMessage(outLines.filter(line => !line.startsWith('export ')).join('\n'));
            common.printFormattedDebug("ZWELS", "zwe-internal-start-prepare,configure_components", outLines.filter(line => line.startsWith('export ')).join('\n'));
          } else {
            //not printformattederror because it makes silly long strings like "ERROR: 2022-12-07 20:00:47 <ZWELS:50791391> me ERROR (zwe-internal-start-prepare,configure_components) Error ZWEL0317E: Component app-server commands.configure ended with rc=22."
            common.printError(`Error ZWEL0317E: Component ${componentId} commands.configure ended with rc=${result.rc}.`);
            if (result.out) {
              const outLines = result.out.split('\n');
              common.printFormattedInfo("ZWELS", "zwe-internal-start-prepare,configure_components", `- commands.configure output from ${componentId} is:`);
              common.printMessage(outLines.filter(line => !line.startsWith('export ')).join('\n'));
            }
            if (ZOWE_CONFIG.zowe.launchScript?.onComponentConfigureFail == 'exit') {
              std.exit(1);
            }
          }
        } else {
          common.printFormattedError("ZWELS", "zwe-internal-start-prepare,configure_components", `Error ZWEL0172E: Component ${componentId} has commands.configure defined but the file is missing.`);
        }
      }
    }
  });
                            
  common.printFormattedDebug("ZWELS", "zwe-internal-start-prepare,configure_components", "component configurations are successful");
}


// Few early steps even before initialization

// init ZWE_RUN_IN_CONTAINER variable
const runtimeDirectory=ZOWE_CONFIG.zowe.runtimeDirectory;
std.setenv('ZWE_zowe_runtimeDirectory', runtimeDirectory);

const extensionDirectory=ZOWE_CONFIG.zowe.extensionDirectory;
std.setenv('ZWE_zowe_extensionDirectory', extensionDirectory);

const workspaceDirectory=ZOWE_CONFIG.zowe.workspaceDirectory;
if (!workspaceDirectory) {
  common.printErrorAndExit("Error ZWEL0157E: Zowe workspace directory (zowe.workspaceDirectory) is not defined in Zowe YAML configuration file.", undefined, 157);
}
std.setenv('ZWE_zowe_workspaceDirectory', workspaceDirectory);


if (fs.fileExists(`${workspaceDirectory}/.init-for-container`)) {
  std.setenv('ZWE_RUN_IN_CONTAINER', 'true');
}

// Fix node.js piles up in IPC message queue
// run this before any node command we start
if (os.platform == 'zos') {
  common.printFormattedTrace("ZWELS", "zwe-internal-start-prepare", "Clean up IPC message queue before using node.js.");
  shell.execSync('sh', `${runtimeDirectory}/bin/utils/cleanup-ipc-mq.sh`);
}


// display starting information
let manifestReturn = shell.execOutSync('cat', `${runtimeDirectory}/manifest.json`);

const runtimeManifest = manifestReturn.rc == 0 ? JSON.parse(manifestReturn.out) : undefined;
const zoweVersion = runtimeManifest ? runtimeManifest.version : undefined;
if (zoweVersion) {
  std.setenv('ZWE_VERSION', ''+zoweVersion);
}

export function execute() {
  common.printFormattedInfo("ZWELS", "zwe-internal-start-prepare", `Zowe version: v${zoweVersion}`);
  common.printFormattedInfo("ZWELS", "zwe-internal-start-prepare", `build and hash: ${runtimeManifest.build.branch}#${runtimeManifest.build.number} (${runtimeManifest.build.commitHash})`);

  // validation
  if (stringlib.itemInList(std.getenv('ZWE_PRIVATE_CORE_COMPONENTS_REQUIRE_JAVA'), std.getenv('ZWE_CLI_PARAMETER_COMPONENT'))) {
    // other extensions need to specify `require_java` in their validate.sh
    java.requireJava();
  }
  node.requireNode();
  common.requireZoweYaml();

  // overwrite ZWE_PRIVATE_LOG_LEVEL_ZWELS with zowe.launchScript.logLevel config in YAML
  if (ZOWE_CONFIG.zowe.launchScript) {
    std.setenv('ZWE_PRIVATE_LOG_LEVEL_ZWELS', ZOWE_CONFIG.zowe.launchScript.logLevel.toUpperCase());
  };

  // check and sanitize ZWE_CLI_PARAMETER_HA_INSTANCE
  config.sanitizeHaInstanceId();
  common.printFormattedInfo("ZWELS", "zwe-internal-start-prepare", `starting Zowe instance ${std.getenv('ZWE_CLI_PARAMETER_HA_INSTANCE')} with ${cliParameterConfig} ...`);

  // extra preparations for running in container 
  // this is running in containers
  if (runInContainer == 'true') {
    prepareRunningInContainer();
  }

  common.printMessage(`In internal start prepare, envs=${JSON.stringify(std.getenviron(), null, 2)}`);

  // init log directory
  prepareLogDirectory();

  // init workspace directory and generate environment variables from YAML
  prepareWorkspaceDirectory();

  // now we can load all variables
  // TODO really this should use configmgr
  config.loadEnvironmentVariables();
  common.printFormattedTrace("ZWELS", "zwe-internal-start-prepare", ">>> all environment variables");
  common.printFormattedTrace("ZWELS", "zwe-internal-start-prepare", JSON.stringify(std.getenviron()));
  common.printFormattedTrace("ZWELS", "zwe-internal-start-prepare", "<<<");

  const enabledComponents=component.getEnabledComponents();

  // main lifecycle
  // global validations
  // no validation for running in container
  globalValidate(enabledComponents);
  // no validation for running in container
  let environments;
  if (runInContainer != 'true') {
    environments = validateComponents(enabledComponents);
  }
  configureComponents(environments, enabledComponents);

  // display instance prepared info
  common.printFormattedInfo("ZWELS", "zwe-internal-start-prepare", "Zowe runtime environment prepared");
}
