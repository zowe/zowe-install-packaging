/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2020
 */

const sshHelper = require('../ssh-helper');

describe('verify utils/component-utils', function() {
  before('prepare SSH connection', async function() {
    await sshHelper.prepareConnection();
  });

  const find_component_directory = 'find_component_directory';
  describe(`verify ${find_component_directory}`, function() {

    it('test with full component lifecycle script path', async function() {
      const component = 'jobs-api';
      await test_component_function_has_expected_rc_stdout_stderr(
        `${find_component_directory} "${process.env.ZOWE_ROOT_DIR}/components/${component}/bin"`,
        {},
        {
          stdout: `${process.env.ZOWE_ROOT_DIR}/components/${component}`,
        },
        false
      );
    });

    it('test with build in component id', async function() {
      const component = 'jobs-api';
      await test_component_function_has_expected_rc_stdout_stderr(
        `${find_component_directory} ${component}`,
        {},
        {
          stdout: `${process.env.ZOWE_ROOT_DIR}/components/${component}`,
        },
        false
      );
    });

    describe('with a dummy extension folder created', async function() {
      const temp_dir = 'delete_1234';
      const extension = 'my-dummy-ext';
      const manifest_file = `${temp_dir}/${extension}/manifest.yaml`;
      before('create component manifest file', async function() {
        await sshHelper.executeCommandWithNoError(`mkdir -p ~/${temp_dir}/${extension} && touch ~/${manifest_file} && chmod u+w ${manifest_file}`);
      });

      after('dispose dummy component', async function() {
        await sshHelper.executeCommandWithNoError(`rm -rf ~/${temp_dir}`);
      });

      it('test with dummy extension', async function() {
        await test_component_function_has_expected_rc_stdout_stderr(
          `${find_component_directory} ${extension}`,
          {
            'ZWE_EXTENSION_DIR': `~/${temp_dir}`,
          },
          {
            stdout: `/${temp_dir}/${extension}`,
          },
          false
        );
      });
    });

  });

  const read_component_manifest = 'read_component_manifest';
  describe(`verify ${read_component_manifest}`, function() {

    it('test reading component name', async function() {
      const component = 'jobs-api';
      await test_component_function_has_expected_rc_stdout_stderr(
        `${read_component_manifest} "${process.env.ZOWE_ROOT_DIR}/components/${component}" ".name"`,
        {},
        {
          stdout: component,
        }
      );
    });

    it('test reading component commands.start', async function() {
      const component = 'jobs-api';
      await test_component_function_has_expected_rc_stdout_stderr(
        `${read_component_manifest} "${process.env.ZOWE_ROOT_DIR}/components/${component}" ".commands.start"`,
        {},
        {
          stdout: 'bin/start.sh',
        }
      );
    });

  });

  async function test_component_function_has_expected_rc_stdout_stderr(command, envs = {}, expected = {}, exact_match = true) {
    await sshHelper.testCommand(
      command,
      {
        envs: Object.assign({
          'INSTANCE_DIR': process.env.ZOWE_INSTANCE_DIR,
          'ROOT_DIR': process.env.ZOWE_ROOT_DIR,
        }, envs),
        sources: [
          process.env.ZOWE_ROOT_DIR + '/bin/internal/prepare-environment.sh'
        ]
      },
      expected,
      exact_match
    );
  }

  after('dispose SSH connection', function() {
    sshHelper.cleanUpConnection();
  });
});
