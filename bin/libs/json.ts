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
import * as common from './common';
import * as stringlib from './string';
import * as shell from './shell';
import * as fakejq from './fakejq';
import * as config from './config';
import * as zosfs from './zos-fs';

// Read JSON configuration from shell script
//
// Note: this is not a reliable way to read JSON file. The JSON file must be
//       properly formatted, each key/value pair takes one line.
//
// FIXME: we should have a language neutral JSON reading tool, not using shell script.
//
// @param string   JSON file name
// @param string   parent key to read after
// @param string   which key to read
// @param string   if this variable is required. If this is true and we cannot
//                 find the value of the key, an error will be displayed.
export function shellReadJsonConfig(jsonFile: string, parentKey: string, key: string, required: boolean): any {
  let val=shell.execOutSync('sh', '-c', `cat "${jsonFile}" | awk "/\"${parentKey}\":/{x=NR+200}(NR<=x){print}" | grep "\"${key}\":" | head -n 1 | awk -F: '{print $2;}' | tr -d '[[:space:]]' | sed -e 's/,$//' | sed -e 's/^"//' -e 's/"$//'`);
  if (!val.out) {
    if (required == true) {
      common.printErrorAndExit(`Error ZWEL0131E: Cannot find key ${parentKey}.${key} defined in file ${jsonFile}.`, undefined, 131);
    }
  } else {
    return val.out;
  }
}


// Read YAML configuration from shell script
//
// Note: this is not a reliable way to read YAML file, but we need this to find
//       out ROOT_DIR to execute further functions.
//
// FIXME: we should have a language neutral YAML reading tool, not using shell script.
//
// @param string   YAML file name
// @param string   parent key to read after
// @param string   which key to read
// @param string   if this variable is required. If this is true and we cannot
//                 find the value of the key, an error will be displayed.
export function shellReadYamlConfig(yamlFile: string, parentKey: string, key: string, required: boolean): any {
  const val=shell.execOutSync('sh', '-c', `cat "${yamlFile}" | awk "/^ *${parentKey}:/{x=NR+2000;next}(NR<=x){print}" | grep -e "^ \+${key}:" | head -n 1 | awk -F: '{print $2;}' | tr -d '[[:space:]]' | sed -e 's/^"//' -e 's/"$//'`);
  if (!val.out) {
    if (required==true) {
      common.printErrorAndExit(`Error ZWEL0131E: Cannot find key ${parentKey}.${key} defined in file ${yamlFile}.`, undefined, 131);
    } else {
      return val;
    }
  }
}

//NOTE: PARMLIB only supported when destination is zowe.yaml
export function readYaml(file: string, key: string) {
  const ZOWE_CONFIG=config.getZoweConfig();
  const utils_dir=`${ZOWE_CONFIG.zowe.runtimeDirectory}/bin/utils`;
  const jq=`${utils_dir}/njq/src/index.js`;
  const fconv=`${utils_dir}/fconv/src/index.js`;

  common.printTrace(`- readYaml load content from ${file}`);
  if (std.getenv('ZWE_CLI_PARAMETER_CONFIG') == file) {
    return fakejq.jqget(ZOWE_CONFIG, key);
  } else {
    const ZWE_PRIVATE_YAML_CACHE=shell.execOutSync('sh', '-c', `node "${fconv}" --input-format=yaml "${file}" 2>&1`);
    let code=ZWE_PRIVATE_YAML_CACHE.rc;
    common.printTrace(`  * Exit code: ${code}`);
    if (code != 0) {
      common.printError("  * Output:");
      common.printError(stringlib.paddingLeft(ZWE_PRIVATE_YAML_CACHE.out, "    "));
      return;
    }

    common.printTrace(`- readYaml ${key} from yaml content`);
    const result=shell.execOutSync('sh', '-c', `echo "${ZWE_PRIVATE_YAML_CACHE}" | node "${jq}" -r "${key}" 2>&1`);
    code=result.rc;
    common.printTrace(`  * Exit code: ${code}`);
    common.printTrace("  * Output:");
    if (result.out) {
      common.printTrace(stringlib.paddingLeft(result.out, "    "));
    }

    return result.out
  }
}

export function readJson(file: string, key: string):any {
  const ZOWE_CONFIG=config.getZoweConfig();
  const utils_dir=`${ZOWE_CONFIG.zowe.runtimeDirectory}/bin/utils`;
  const jq=`${utils_dir}/njq/src/index.js`;

  common.printTrace(`- readJson ${key} from ${file}`);
  let result=shell.execOutSync('sh', '-c', `cat "${file}" | node "${jq}" -r "${key}" 2>&1`);
  const code = result.rc;
  common.printTrace(`  * Exit code: ${code}`);
  common.printTrace(`  * Output:`);
  if ( result.out ) {
    common.printTrace(stringlib.paddingLeft(result.out, "    "));
  }

  return result.out;
}

export function readJsonString(input: string, key: string): any {
  return fakejq.jqget(JSON.parse(input), key);
}

//NOTE: PARMLIB only supported when destination is zowe.yaml
export function updateYaml(file: string, key: string, val: any, expectedSample: string) {
  const ZOWE_CONFIG=config.getZoweConfig();
  const utils_dir=`${ZOWE_CONFIG.zowe.runtimeDirectory}/bin/utils`;
  const config_converter=`${utils_dir}/config-converter/src/cli.js`

  
  common.printMessage(`- update "${key}" with value: ${val}`);
  if (std.getenv('ZWE_CLI_PARAMETER_CONFIG') == file) {
    updateZoweYaml(file, key, val);
  } else {
    // TODO what would we write thats not the zowe config? this sounds like an opportunity to disorganize.
    let result=shell.execOutSync('sh', '-c', `node "${config_converter}" yaml update "${file}" "${key}" "${val}"`);
    const code = result.rc;
    if (code == 0) {
      common.printTrace(`  * Exit code: ${code}`);
      common.printTrace(`  * Output:`);
      if (result.out) {
        common.printTrace(stringlib.paddingLeft(result.out, "    "));
      }
    } else {
      common.printError(`  * Exit code: ${code}`);
      common.printError("  * Output:");
      if (result.out) {
        common.printError(stringlib.paddingLeft(result.out, "    "));
      }
      common.printErrorAndExit(`Error ZWEL0138E: Failed to update key ${key} of file ${file}.`, undefined, 138);
    }

    zosfs.ensureFileEncoding(file, expectedSample);
  }
}

export function updateZoweYaml(file: string, key: string, val: any) {
  common.printMessage(`- update zowe config ${file}, key: "${key}" with value: ${val}`);
  let [ success, updateObj ] = fakejq.jqset({}, key, val);
  
  if (success) {
    common.printMessage(`  * Success`);
    config.updateZoweConfig(updateObj, true, 1); //TODO externalize array merge strategy = 1
  } else {
    common.printError(`  * Error`); 
  }
}

export function updateZoweYamlFromObj(file: string, updateObj: any) {
  common.printMessage(`- update zowe config ${file} with obj=${JSON.stringify(updateObj, null, 2)}`);
  config.updateZoweConfig(updateObj, true, 1); //TODO externalize array merge strategy = 1
}


//TODO: PARMLIB not supported.
export function deleteYaml(file: string, key: string, expectedSample: string) {
  const ZOWE_CONFIG=config.getZoweConfig();
  const utils_dir=`${ZOWE_CONFIG.zowe.runtimeDirectory}/bin/utils`;
  const config_converter=`${utils_dir}/config-converter/src/cli.js`

  common.printMessage(`- delete \"${key}\"`);
  let result=shell.execOutSync('sh', '-c', `node "${config_converter}" yaml delete "${file}" "${key}"`);
  const code = result.rc;
  if (code == 0) {
    common.printTrace(`  * Exit code: ${code}`);
    common.printTrace(`  * Output:`);
    if (result.out) {
      common.printTrace(stringlib.paddingLeft(result.out, "    "));
    }
  } else {
    common.printError(`  * Exit code: ${code}`);
    common.printError("  * Output:");
    if (result.out) {
      common.printError(stringlib.paddingLeft(result.out, "    "));
    }
    common.printErrorAndExit(`Error ZWEL0138E: Failed to delete key ${key} of file ${file}.`, undefined, 138);
  }

  zosfs.ensureFileEncoding(file, expectedSample);
}

export function deleteZoweYaml(file: string, key: string) {
  deleteYaml(file, key, "zowe:");
}
