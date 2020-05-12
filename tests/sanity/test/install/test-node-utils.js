/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2020
 */

const sshHelper = require('./ssh-helper');

describe.only('verify node-utils', function() { //TODO NOW - remove only
  before('prepare SSH connection', async function() {
    await sshHelper.prepareConnection();
  });

  const ensure_node_is_on_path = 'ensure_node_is_on_path';
  describe(`verify ${ensure_node_is_on_path}`, function() {

    let start_path, start_node_home;
    before('get required parameters', async function() {
      start_path = await sshHelper.executeCommandWithNoError('echo $PATH');
      start_node_home = await sshHelper.executeCommandWithNoError('echo $NODE_HOME');
    });

    it('test node added to path if required', async function() {
      const node_home = '/junk_path1/node';
      await test_node_added_to_path(node_home, true);
    });

    it('test node added to path if bin missing', async function() {
      const path_pre_addition = '/junk_path2/node';
      const node_home = '/junk_path2/node';
      await test_node_added_to_path(node_home, true, path_pre_addition);
    });

    it('test node not added to path if already there', async function() {
      const path_pre_addition = '/junk_path3/node/bin';
      const node_home = '/junk_path3/node';
      await test_node_added_to_path(node_home, false, path_pre_addition);
    });

    after('restore env', async function() {
      await sshHelper.executeCommandWithNoError(`export PATH=${start_path}`);
      await sshHelper.executeCommandWithNoError(`export NODE_HOME=${start_node_home}`);
    });

    async function test_node_added_to_path(node_home, expected_addition, path_pre_addition = '') {
      let command = path_pre_addition === '' ? '' : `export PATH=$PATH:${path_pre_addition} && `;
      command += `export NODE_HOME=${node_home} && ${ensure_node_is_on_path}`;
      const expected_out = expected_addition ? 'Appending NODE_HOME/bin to the PATH...' : '';
      await test_node_utils_function_has_expected_rc_stdout_stderr(command, 0, expected_out, '');
    }
  });
  
  async function test_node_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_stdout, expected_stderr) {
    const variable_utils_path = process.env.ZOWE_ROOT_DIR+'/bin/utils/node-utils.sh';
    command = `. ${variable_utils_path} && ${command}`;
    await sshHelper.testCommand(command, expected_rc, expected_stdout, expected_stderr);
  }

  after('dispose SSH connection', function() {
    sshHelper.cleanUpConnection();
  });
});
