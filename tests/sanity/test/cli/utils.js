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
const debug = require('debug')('test:cli:utils');
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

  let keyringExists = false;

  try {
    keyringExists = await exec('which gnome-keyring-daemon');
    if (keyringExists && keyringExists.stdout && keyringExists.stdout.trim() !== '') {
      keyringExists = await exec('which dbus-launch');
      if (keyringExists && keyringExists.stdout && keyringExists.stdout.trim() !== '') {
        keyringExists = true;
      }
    }
  } catch (e) {
    keyringExists = false;
  }

  try {
    if (keyringExists) {
      const fn = path.join(__dirname, wrapperFileName);

      await writeFile(fn, wrapperFileContent + command);
      await chmod(fn, 0o755);
      result = await exec(`dbus-launch ${fn}`);
    } else {
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

// default z/OSMF CLI profile name
const defaultZOSMFProfileName = 'zowe-install-test';

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
  const command = [
    'zowe',
    'profiles',
    'create',
    'zosmf-profile',
    profile || defaultZOSMFProfileName,
    '--host',
    hostname,
    '--port',
    port,
    '--user',
    username,
    '--pass',
    password,
    '--reject-unauthorized',
    'false',
    '--overwrite',
  ];

  return await execZoweCli(command.join(' '));
};

// export constants and methods
module.exports = {
  execZoweCli,
  defaultZOSMFProfileName,
  createDefaultZOSMFProfile,
};
