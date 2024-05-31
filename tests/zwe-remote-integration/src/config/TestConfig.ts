/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import * as path from 'path';
import * as fs from 'fs-extra';
import * as yaml from 'yaml';
import yn from 'yn';
import { findDirWalkingUpOrThrow } from '../utils';
import ZoweYamlType from './ZoweYamlType';
class ConfigItem<T> {
  public readonly name: string;
  public readonly required: boolean;
  public readonly default: T;

  constructor(name: string, required: boolean = false, defaultVal: T = undefined) {
    this.name = name;
    this.required = required;
    this.default = defaultVal;
  }
}
const configFields: ConfigItem<unknown>[] = [
  new ConfigItem('zos_java_home', false),
  new ConfigItem('zos_node_home', false),
  new ConfigItem('zos_host', true),
  new ConfigItem('zos_user', true),
  new ConfigItem('zos_password', true),
  new ConfigItem('ssh_port', true),
  new ConfigItem('zosmf_port', true),
  new ConfigItem('remote_test_dir', true),
  new ConfigItem('test_ds_hlq', true),
  new ConfigItem('test_volume', true),
  new ConfigItem('zosmf_reject_unauthorized', false, false),
  new ConfigItem('download_configmgr', false, true),
  new ConfigItem('download_zowe_tools', false, true),
  new ConfigItem('remote_setup', false),
  new ConfigItem('remote_teardown', false),
  new ConfigItem('jfrog_user', false),
  new ConfigItem('jfrog_token', false),
  new ConfigItem('collect_test_spool', false, true),
  new ConfigItem('zowe_yaml_overrides', false),
];

export const REPO_ROOT_DIR: string = findDirWalkingUpOrThrow('zowe-install-packaging');
export const THIS_TEST_ROOT_DIR: string = findDirWalkingUpOrThrow('zwe-remote-integration'); // JEST runs in the src dir
const configFile = process.env['TEST_CONFIG_FILE'] || `${THIS_TEST_ROOT_DIR}/resources/test_config.yml`;
const configData = getConfig(configFile);

export const THIS_TEST_BASE_YAML: string = path.resolve(THIS_TEST_ROOT_DIR, '.build', 'zowe.yaml.base');
export const TEST_OUTPUT_DIR: string = path.resolve(THIS_TEST_ROOT_DIR, '.build', 'output');
export const INSTALL_TEST_ROOT_DIR: string = path.resolve(__dirname, '../');
export const LINGERING_REMOTE_FILES_FILE = path.resolve(THIS_TEST_ROOT_DIR, '.build', 'lingering_ds.txt');
export const TEST_JOBS_RUN_FILE = path.resolve(THIS_TEST_ROOT_DIR, '.build', 'jobs-run.txt');
export const DOWNLOAD_ZOWE_TOOLS = yn(configData.download_zowe_tools, { default: true });
export const DOWNLOAD_CONFIGMGR = yn(configData.download_configmgr, { default: true });
export const TEST_DATASETS_HLQ = configData.test_ds_hlq || configData.zos_user + '.ZWETESTS';
export const REMOTE_SETUP = yn(configData.remote_setup, { default: true });
export const REMOTE_TEARDOWN = yn(configData.remote_teardown, { default: true });
export const ZOWE_YAML_OVERRIDES = configData.zowe_yaml_overrides;
export const TEST_COLLECT_SPOOL = yn(configData.collect_test_spool);
export const JFROG_CREDENTIALS = {
  user: configData.jfrog_user,
  token: configData.jfrog_token,
};
const ru = yn(configData.zosmf_reject_unauthorized, { default: false });

export const REMOTE_SYSTEM_INFO = {
  zosJavaHome: configData.zos_java_home,
  zosNodeHome: configData.zos_node_home,
  volume: configData.test_volume,
  prefix: configData.test_ds_hlq,
  szweexec: `${configData.test_ds_hlq}.SZWEEXEC`,
  szwesamp: `${configData.test_ds_hlq}.SZWESAMP`,
  jcllib: `${configData.test_ds_hlq}.JCLLIB`,
  szweload: `${configData.test_ds_hlq}.SZWELOAD`,
  ussTestDir: configData.remote_test_dir,
  hostname: configData.zos_host,
  zosmfPort: configData.zosmf_port,
};

export const REMOTE_CONNECTION_CFG = {
  host: configData.zos_host,
  ssh_port: Number(configData.ssh_port),
  zosmf_port: Number(configData.zosmf_port),
  user: configData.zos_user,
  password: configData.zos_password,
  zosmf_reject_unauthorized: ru,
};

type TestConfigData = {
  zos_java_home: string;
  zos_node_home: string;
  zos_host: string;
  zos_user: string;
  zos_password: string;
  ssh_port: string;
  zosmf_port: string;
  remote_test_dir: string;
  test_ds_hlq: string;
  test_volume: string;
  zosmf_reject_unauthorized: string;
  download_configmgr: string;
  download_zowe_tools: boolean;
  remote_setup: boolean;
  remote_teardown: boolean;
  jfrog_user: string;
  jfrog_token: string;
  collect_test_spool: string;
  zowe_yaml_overrides: Partial<ZoweYamlType>;
};

function getConfig(configFile: string): TestConfigData {
  const rawConfig = yaml.parse(fs.readFileSync(configFile, 'utf8'));
  const configData: { [key: string]: string } = {};

  for (const configItem of configFields) {
    const paramName = configItem.name;
    configData[paramName] = rawConfig[paramName];
    const envValue = process.env[paramName.toUpperCase()]?.trim();
    if (envValue != null && envValue.length > 0) {
      configData[paramName] = envValue;
    }

    if (configData[paramName] == null && configItem.required === true) {
      console.log(`Must set the ${paramName} configuration variable in the ${configFile}
              or set it via environment variable ${paramName.toUpperCase()}`);
      throw Error(`Required configuration parameter unset`);
    }
  }
  // coerce typing, will throw an error fast if something's wrong
  return configData as unknown as TestConfigData;
}
