/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2020
 */

const { expect } = require('chai');
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

    it('test reading non-existing component manifest entry', async function() {
      const component = 'jobs-api';
      await test_component_function_has_expected_rc_stdout_stderr(
        `${read_component_manifest} "${process.env.ZOWE_ROOT_DIR}/components/${component}" ".commands.somethingDoesNotExist"`,
        {},
        {
          stdout: 'null',
        }
      );
    });

    it('test reading component manifest entry with wrong definition', async function() {
      const component = 'jobs-api';
      await test_component_function_has_expected_rc_stdout_stderr(
        `${read_component_manifest} "${process.env.ZOWE_ROOT_DIR}/components/${component}" ".commands[].start"`,
        {},
        {
          rc: 1,
          stderr: 'Error: Cannot iterate over object',
        }
      );
    });

  });

  const convert_component_manifest = 'convert_component_manifest';
  describe(`verify ${convert_component_manifest}`, function() {
    const dummy_component_name = 'sanity_test_dummy';
    const component_runtime_dir = `${process.env.ZOWE_ROOT_DIR}/components/${dummy_component_name}`;
    const component_instance_dir = `${process.env.ZOWE_INSTANCE_DIR}/workspace/${dummy_component_name}`;

    before('create test component', async function() {
      await sshHelper.executeCommandWithNoError(`mkdir -p ${component_runtime_dir} && rm -fr ${component_instance_dir} && echo 'name: ${dummy_component_name}' > ${component_runtime_dir}/manifest.yaml`);
    });

    after('dispose test component', async function() {
      await sshHelper.executeCommandWithNoError(`rm -rf ${component_runtime_dir} && rm -fr ${component_instance_dir}`);
    });

    it('test creating component manifest.json', async function() {
      await test_component_function_has_expected_rc_stdout_stderr(
        `${convert_component_manifest} "${component_runtime_dir}"`
      );

      const jsonContent = await sshHelper.executeCommandWithNoError(`_BPXK_AUTOCVT=ON cat ${component_instance_dir}/.manifest.json`);
      expect(jsonContent).to.be.equal(`{\n  "name": "${dummy_component_name}"\n}`);
    });

  });

  const process_component_apiml_static_definitions = 'process_component_apiml_static_definitions';
  describe(`verify ${process_component_apiml_static_definitions}`, function() {
    const dummy_component_name = 'sanity_test_dummy';
    const component_runtime_dir = `${process.env.ZOWE_ROOT_DIR}/components/${dummy_component_name}`;
    const static_def_file = 'static-def.yaml';
    // this may change in the future
    const static_def_dir = `${process.env.ZOWE_INSTANCE_DIR}/workspace/api-mediation/api-defs`;
    const target_static_def_file = `${dummy_component_name}_static_def_yaml.yml`;

    before('create test component', async function() {
      await sshHelper.executeCommandWithNoError(`mkdir -p ${component_runtime_dir} && echo 'name: ${dummy_component_name}\napimlServices:\n  static:\n  - file: ${static_def_file}' > ${component_runtime_dir}/manifest.yaml && echo 'services: does not matter' > ${component_runtime_dir}/${static_def_file}`);
    });

    after('dispose test component', async function() {
      await sshHelper.executeCommandWithNoError(`rm -rf ${component_runtime_dir} && rm -fr ${static_def_dir}/${target_static_def_file}`);
    });

    it('test creating component manifest.json', async function() {
      await test_component_function_has_expected_rc_stdout_stderr(
        `${process_component_apiml_static_definitions} "${component_runtime_dir}"`,
        {},
        {
          stdout: `process ${dummy_component_name} service static definition file ${static_def_file} ...`
        }
      );

      const jsonContent = await sshHelper.executeCommandWithNoError(`_BPXK_AUTOCVT=ON iconv -f IBM-850 -t IBM-1047 ${static_def_dir}/${target_static_def_file}`);
      expect(jsonContent).to.be.equal('services: does not matter');
    });

  });

  const process_component_desktop_iframe_plugin = 'process_component_desktop_iframe_plugin';
  describe.only(`verify ${process_component_desktop_iframe_plugin}`, function() {
    const dummy_component_name = 'sanity_test_dummy';
    const dummy_component_title = 'Sanity Test Dummy';
    const dummy_component_id = 'org.zowe.plugins.sanity_test_dummy';
    const dummy_component_url = '/ui/v1/dummy';
    const component_runtime_dir = `${process.env.ZOWE_ROOT_DIR}/components/${dummy_component_name}`;
    const component_instance_dir = `${process.env.ZOWE_INSTANCE_DIR}/workspace/${dummy_component_name}`;
    const app_server_plugins_dir = `${process.env.ZOWE_INSTANCE_DIR}/workspace/app-server/plugins`;

    before('create test component', async function() {
      await sshHelper.executeCommandWithNoError(`mkdir -p ${component_runtime_dir} && rm -fr ${component_instance_dir} && echo 'name: ${dummy_component_name}\nid: ${dummy_component_id}\ntitle: ${dummy_component_title}\ndesktopIframePlugins:\n- url: ${dummy_component_url}\n  icon: image.png' > ${component_runtime_dir}/manifest.yaml && echo 'dummy' > ${component_runtime_dir}/image.png`);
    });

    after('dispose test component', async function() {
      await sshHelper.executeCommandWithNoError(`rm -rf ${component_runtime_dir} && rm -fr ${component_instance_dir} && rm -fr ${app_server_plugins_dir}/${dummy_component_id}.json`);
    });

    it('test creating component manifest.json', async function() {
      await test_component_function_has_expected_rc_stdout_stderr(
        `${process_component_desktop_iframe_plugin} "${component_runtime_dir}"`,
        {},
        {
          stdout: 'process desktop plugin #0'
        },
        false
      );

      const pluginDefinitionContent = await sshHelper.executeCommandWithNoError(`_BPXK_AUTOCVT=ON cat ${component_instance_dir}/pluginDefinition.json`);
      expect(pluginDefinitionContent).to.have.string(`"identifier": "${dummy_component_id}",`);

      const pluginIndexHtml = await sshHelper.executeCommandWithNoError(`_BPXK_AUTOCVT=ON cat ${component_instance_dir}/web/index.html`);
      expect(pluginIndexHtml).to.have.string(dummy_component_url);

      const pluginRegistryContent = await sshHelper.executeCommandWithNoError(`_BPXK_AUTOCVT=ON cat ${app_server_plugins_dir}/${dummy_component_id}.json`);
      expect(pluginRegistryContent).to.have.string(`"identifier": "${dummy_component_id}",`);
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
