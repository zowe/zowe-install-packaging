/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018, 2019
 */

const fs = require('fs');
const path = require('path');
const debug = require('debug')('zowe-sanity-test:cli:utils');
const util = require('util');
const exec = util.promisify(require('child_process').exec);
const writeFile = util.promisify(fs.writeFile);
const chmod = util.promisify(fs.chmod);

// script name to wrap CLI command
const wrapperFileName = 'zowe-cli-command-wrapper.sh';
// how to wrap CLI command
const wrapperFileContent = `#!/usr/bin/env bash

# Unlock the keyring
echo 'jenkins' | gnome-keyring-daemon --unlock

# Your commands here
`;

/**
 * Execute Zowe CLI command
 *
 * @param  {String} command cli command line
 * @return {Object}         exec result object with stdout, stderr properties
 */
const execZoweCli = async(command) => {
  let result;

  // To suppress the warning message of:
  //
  // (node:69716) Warning: Setting the NODE_TLS_REJECT_UNAUTHORIZED environment
  // variable to \'0\' makes TLS connections and HTTPS requests insecure by
  // disabling certificate verification.
  //
  // showing in stderr.
  process.env.NODE_TLS_REJECT_UNAUTHORIZED = '1';

  let keyringExists = false;

  try {
    const gnomeKeyringDaemonExists = await exec('which gnome-keyring-daemon');
    if (!gnomeKeyringDaemonExists || !gnomeKeyringDaemonExists.stdout || gnomeKeyringDaemonExists.stdout.trim() === '') {
      throw new Error('gnome-keyring-daemon not found');
    }
    const dbusLaunchExists = await exec('which dbus-launch');
    if (!dbusLaunchExists || !dbusLaunchExists.stdout || dbusLaunchExists.stdout.trim() === '') {
      throw new Error('dbus-launch not found');
    }
    const checkPermission = await exec('echo "jenkins" | gnome-keyring-daemon --unlock');
    if (!checkPermission || checkPermission.stderr.trim() !== '') {
      // if failed, the stderr has a value of "/usr/bin/gnome-keyring-daemon: Operation not permitted"
      throw new Error('cannot unlock gnome-keyring-daemon');
    }
    keyringExists = true;
  } catch (e) {
    keyringExists = false;
  }

  try {
    if (keyringExists) {
      debug(`run cli with dbus-launch: ${command}`);

      const fn = path.join(__dirname, wrapperFileName);

      await writeFile(fn, wrapperFileContent + command);
      await chmod(fn, 0o755);
      result = await exec(`dbus-launch ${fn}`);
    } else {
      debug(`run cli directly: ${command}`);

      result = await exec(command);
    }
  } catch (e) {
    result = e;
  }

  debug('cli result:', result);

  // remove unlock keyring info from stdout
  if (keyringExists && result && result.stdout) {
    let lines = result.stdout.split('\n');
    while (lines && lines[0] &&
      (lines[0].startsWith('GNOME_KEYRING_CONTROL=') || lines[0].startsWith('SSH_AUTH_SOCK='))) {
      lines.splice(0, 1);
    }
    result.stdout = lines.join('\n');
  }

  return result;
};

const globalZoweCliConfigFile = '.zowe/zowe.config.json';
// default z/OSMF CLI profile name, separated by process pid
const defaultZOSMFProfileName = `zowe-install-test-ZOSMF-${process.pid}`;
const defaultSSHProfileName = `zowe-install-test-SSH-${process.pid}`;
const defaultTSOProfileName = `zowe-install-test-TSO-${process.pid}`;

/**
 * Init CLI configuration with "zowe config init" command
 *
 * @return {Object}         exec result object with stdout, stderr properties
 */
const initZoweCliConfig = async() => {
  const testHomeDir = await exec('cd ~ && pwd');
  debug(`User home directory is ${testHomeDir.stdout.trim()}`);
  if (fs.existsSync(`${testHomeDir.stdout.trim()}/${globalZoweCliConfigFile}`)) {
    debug(`${testHomeDir.stdout.trim()}/${globalZoweCliConfigFile} already exists, skipping zowe config init`);
    return;
  }

  const command = [
    'zowe',
    'config',
    'init',
    '--global-config',
    '--overwrite',
    '--for-sure',
    '--prompt',
    'false',
  ];

  return await execZoweCli(command.join(' '));
};

/**
 * Create z/OSMF CLI profile
 *
 * @param  {String} hostname  z/OSMF hostname
 * @param  {String} port      z/OSMF port
 * @param  {String} username  username
 * @param  {String} password  password
 * @param  {String} profile   profile name, optional
 * @return {Object}         exec result object with stdout, stderr properties
 */
const createDefaultZOSMFProfile = async(hostname, port, username, password, profile) => {
  // init v2 config
  await initZoweCliConfig();

  const command = [
    'zowe',
    'config',
    'set',
    `"profiles.${profile || defaultZOSMFProfileName}"`,
    '"' + JSON.stringify({
      type: 'zosmf',
      properties: {
        host: hostname,
        port: parseInt(port, 10),
        user: username,
        password: password,
        rejectUnauthorized: false,
      },
      secure: []
    }).replace(/"/g, '\\"') + '"',
    '--json',
    '--global-config',
  ];

  return await execZoweCli(command.join(' '));
};

/**
 * Create SSH profile
 *
 * @param  {String} hostname  SSH hostname
 * @param  {String} port      SSH port
 * @param  {String} username  username
 * @param  {String} password  password
 * @param  {String} profile   profile name, optional
 * @return {Object}         exec result object with stdout, stderr properties
 */
const createDefaultSSHProfile = async(hostname, username, password, port, profile) => {
  // init v2 config
  await initZoweCliConfig();

  const command = [
    'zowe',
    'config',
    'set',
    `"profiles.${profile || defaultSSHProfileName}"`,
    '"' + JSON.stringify({
      type: 'ssh',
      properties: {
        host: hostname,
        port: parseInt(port || 22, 10),
        user: username,
        password: password,
      },
      secure: []
    }).replace(/"/g, '\\"') + '"',
    '--json',
    '--global-config',
  ];

  return await execZoweCli(command.join(' '));
};

/**
 * Create TSO profile
 *
 * @param  {String} accountname  TSO account
 * @param  {String} profile   profile name, optional
 * @return {Object}         exec result object with stdout, stderr properties
 */
const createDefaultTSOProfile = async(accountname, profile) => {
  // init v2 config
  await initZoweCliConfig();

  const command = [
    'zowe',
    'config',
    'set',
    `"profiles.${profile || defaultTSOProfileName}"`,
    '"' + JSON.stringify({
      type: 'tso',
      properties: {
        account: accountname,
      },
      secure: []
    }).replace(/"/g, '\\"') + '"',
    '--json',
    '--global-config',
  ];

  return await execZoweCli(command.join(' '));
};

// export constants and methods
module.exports = {
  execZoweCli,
  globalZoweCliConfigFile,
  defaultZOSMFProfileName,
  defaultSSHProfileName,
  defaultTSOProfileName,
  initZoweCliConfig,
  createDefaultZOSMFProfile,
  createDefaultSSHProfile,
  createDefaultTSOProfile,
};
