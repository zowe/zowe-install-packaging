/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2020
 */

const expect = require('chai').expect;
const debug = require('debug')('zowe-sanity-test:install:ssh-helper');
const SSH = require('node-ssh');
const ssh = new SSH();

const prepareConnection = () => {
  expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
  expect(process.env.SSH_PORT, 'SSH_PORT is not defined').to.not.be.empty;
  expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
  expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
  expect(process.env.ZOWE_ROOT_DIR, 'ZOWE_ROOT_DIR is not defined').to.not.be.empty;
  expect(process.env.ZOWE_INSTANCE_DIR, 'ZOWE_INSTANCE_DIR is not defined').to.not.be.empty;

  const password = process.env.SSH_PASSWD;

  return ssh.connect({
    host: process.env.SSH_HOST,
    username: process.env.SSH_USER,
    port: process.env.SSH_PORT,
    password,
    tryKeyboard: true,
    onKeyboardInteractive: (name, instructions, instructionsLang, prompts, finish) => {
      if (prompts.length > 0 && prompts[0].prompt.toLowerCase().includes('password')) {
        finish([password]);
      }
    }
  })
    .then(function() {
      debug('ssh connected');
    });
};

const cleanUpConnection = () => {
  ssh.dispose();
};

// Runs the command, ensures rc = 0 and there is no stderr and returns stdout value
const executeCommandWithNoError = async(command) => {
  const {rc, stdout, stderr} = await executeCommand(command);
  expect(rc).to.equal(0);
  expect(stderr).to.be.empty;
  return stdout;
};

const executeCommand = async (command) => {
  const result = await ssh.execCommand(command);
  const rc = result.code;
  const stdout = result.stdout;
  const stderr = result.stderr;
  debug(`Executed '${command}'\nrc:${rc}\nstdout:'${stdout}'\nstderr:'${stderr}'`);
  return {rc, stdout, stderr};
};

const testCommand = async(command, expected_rc, expected_stdout, expected_stderr, exact_match = false) => {
  const {rc, stdout, stderr} = await executeCommand(command);
  expect(rc).to.equal(expected_rc);
  if (exact_match) {
    expect(stdout).to.equal(expected_stdout);
    expect(stderr).to.equal(expected_stderr);
  } else {
    await expectStringMatchExceptEmpty(stdout, expected_stdout);
    await expectStringMatchExceptEmpty(stderr, expected_stderr);
  }
};

// If a string is specified we want to check that that was part of the actual, but if it was empty we want to check that we actually got empty, so that we can't match on any error
const expectStringMatchExceptEmpty = async (actual, expected) => {
  if (expected === '') {
    expect(actual).to.be.empty;
  } else {
    expect(actual).to.have.string(expected);
  }
};

// export constants and methods
module.exports = {
  prepareConnection,
  cleanUpConnection,
  executeCommand,
  executeCommandWithNoError,
  testCommand
};
