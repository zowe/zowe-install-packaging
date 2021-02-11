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
// const debug = require('debug')('zowe-sanity-test:utils-scripts:component-utils');

describe('verify utils/component-utils', function() {
  let TMP_DIR;
  const TMP_EXT_DIR = 'sanity_test_extensions';
  const dummy_component_name = 'sanity_test_dummy';
  let component_runtime_dir;
  let component_instance_dir;

  before('prepare SSH connection', async function() {
    await sshHelper.prepareConnection();

    // retrieve tmp dir on server side
    TMP_DIR = await sshHelper.getTmpDir();
    component_runtime_dir = `${TMP_DIR}/${TMP_EXT_DIR}/${dummy_component_name}`;
    component_instance_dir = `${process.env.ZOWE_INSTANCE_DIR}/workspace/${dummy_component_name}`;
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
      const manifest_file = 'manifest.yaml';
      before('create component manifest file', async function() {
        await sshHelper.executeCommandWithNoError(`rm -rf ${component_runtime_dir} && mkdir -p ${component_runtime_dir} && cd ${component_runtime_dir} && touch ${manifest_file} && chmod u+w ${manifest_file}`);
      });

      after('dispose dummy component', async function() {
        await sshHelper.executeCommandWithNoError(`rm -rf ${TMP_DIR}/${TMP_EXT_DIR}`);
      });

      it('test with dummy extension', async function() {
        await test_component_function_has_expected_rc_stdout_stderr(
          `${find_component_directory} ${dummy_component_name}`,
          {
            'ZWE_EXTENSION_DIR': `${TMP_DIR}/${TMP_EXT_DIR}`,
          },
          {
            stdout: `${component_runtime_dir}`,
          },
          false
        );
      });
    });

  });

  const is_core_component = 'is_core_component';
  describe(`verify ${is_core_component}`, function() {
    before('create test component', async function() {
      await sshHelper.executeCommandWithNoError(`rm -rf ${component_runtime_dir} && mkdir -p ${component_runtime_dir} && rm -fr ${component_instance_dir} && echo 'name: ${dummy_component_name}' > ${component_runtime_dir}/manifest.yaml`);
    });

    after('dispose test component', async function() {
      await sshHelper.executeCommandWithNoError(`rm -rf ${component_runtime_dir} && rm -fr ${component_instance_dir}`);
    });

    it('test with core component', async function() {
      const component = 'jobs-api';
      await test_component_function_has_expected_rc_stdout_stderr(
        'echo $' + `(${is_core_component} "` + '$' + `(find_component_directory ${component})")`,
        {},
        {
          stdout: 'true',
        }
      );
    });

    it('test with non-core component', async function() {
      await test_component_function_has_expected_rc_stdout_stderr(
        'echo $' + `(${is_core_component} "` + '$' + `(find_component_directory ${dummy_component_name})")`,
        {},
        {
          stdout: 'false',
        }
      );
    });

  });

  const read_component_manifest = 'read_component_manifest';
  describe(`verify ${read_component_manifest}`, function() {

    it('test reading component name', async function() {
      const component = 'jobs-api';
      await test_component_function_has_expected_rc_stdout_stderr(
        'echo $' + `(${read_component_manifest} "${process.env.ZOWE_ROOT_DIR}/components/${component}" ".name")`,
        {},
        {
          stdout: component,
        }
      );
    });

    it('test reading component commands.start', async function() {
      const component = 'jobs-api';
      await test_component_function_has_expected_rc_stdout_stderr(
        'echo $' + `(${read_component_manifest} "${process.env.ZOWE_ROOT_DIR}/components/${component}" ".commands.start")`,
        {},
        {
          stdout: 'bin/start.sh',
        }
      );
    });

    it('test reading non-existing component manifest entry', async function() {
      const component = 'jobs-api';
      await test_component_function_has_expected_rc_stdout_stderr(
        'echo $' + `(${read_component_manifest} "${process.env.ZOWE_ROOT_DIR}/components/${component}" ".commands.somethingDoesNotExist")`,
        {},
        {
          stdout: 'null',
        }
      );
    });

    it('test reading component manifest entry with wrong definition', async function() {
      const component = 'jobs-api';
      await test_component_function_has_expected_rc_stdout_stderr(
        'echo $' + `(${read_component_manifest} "${process.env.ZOWE_ROOT_DIR}/components/${component}" ".commands[].start" 2>&1)`,
        {},
        {
          rc: 0,
          stdout: 'Error: Cannot iterate over object',
        }
      );
    });

  });

  const detect_component_manifest_encoding = 'detect_component_manifest_encoding';
  describe(`verify ${detect_component_manifest_encoding}`, function() {
    beforeEach('create test component', async function() {
      await sshHelper.executeCommandWithNoError(`rm -rf ${component_runtime_dir} && mkdir -p ${component_runtime_dir}`);
    });

    afterEach('dispose test component', async function() {
      await sshHelper.executeCommandWithNoError(`rm -rf ${component_runtime_dir}`);
    });

    it('test detecting component manifest.yaml encoding with default setup', async function() {
      // prepare manifest.yaml in default (IBM-1047) encoding
      await sshHelper.executeCommandWithNoError(`echo 'name: ${dummy_component_name}' > ${component_runtime_dir}/manifest.yaml`);

      await test_component_function_has_expected_rc_stdout_stderr(
        `${detect_component_manifest_encoding} "${component_runtime_dir}"`,
        {
          'ZWE_EXTENSION_DIR': `${TMP_DIR}/${TMP_EXT_DIR}`,
        },
        {
          stdout: 'IBM-1047',
        }
      );
    });
    it('test detecting component manifest.yaml encoding with customized encoding setup', async function() {
      // prepare manifest.yaml in default (IBM-1047) encoding
      await sshHelper.executeCommandWithNoError(`cd ${component_runtime_dir} && echo 'name: ${dummy_component_name}' > manifest.yaml.1047 && iconv -f IBM-1047 -t ISO8859-1 manifest.yaml.1047 > manifest.yaml && rm manifest.yaml.1047`);

      await test_component_function_has_expected_rc_stdout_stderr(
        `${detect_component_manifest_encoding} "${component_runtime_dir}"`,
        {
          'ZWE_EXTENSION_DIR': `${TMP_DIR}/${TMP_EXT_DIR}`,
        },
        {
          stdout: 'ISO8859-1',
        }
      );
    });

    it('test detecting files-api manifest.yaml encoding', async function() {
      // files-api is shipped as ZIP and it should be automatically tagged as ISO8859-1 encoding during installation
      await test_component_function_has_expected_rc_stdout_stderr(
        `${detect_component_manifest_encoding} "${process.env.ZOWE_ROOT_DIR}/components/files-api"`,
        {},
        {
          stdout: 'ISO8859-1',
        }
      );
    });

    it('test detecting explorer-jes manifest.yaml encoding', async function() {
      // explorer-jes is shipped as PAX and it's already in IBM-1047 encoding
      await test_component_function_has_expected_rc_stdout_stderr(
        `${detect_component_manifest_encoding} "${process.env.ZOWE_ROOT_DIR}/components/explorer-jes"`,
        {},
        {
          stdout: 'IBM-1047',
        }
      );
    });

  });

  const convert_component_manifest = 'convert_component_manifest';
  describe(`verify ${convert_component_manifest}`, function() {
    before('create test component', async function() {
      await sshHelper.executeCommandWithNoError(`rm -rf ${component_runtime_dir} && mkdir -p ${component_runtime_dir} && rm -fr ${component_instance_dir} && echo 'name: ${dummy_component_name}' > ${component_runtime_dir}/manifest.yaml`);
    });

    after('dispose test component', async function() {
      await sshHelper.executeCommandWithNoError(`rm -rf ${component_runtime_dir} && rm -fr ${component_instance_dir}`);
    });

    it('test creating component .manifest.json in workspace', async function() {
      await test_component_function_has_expected_rc_stdout_stderr(
        `${convert_component_manifest} "${component_runtime_dir}"`,
        {
          'ZWE_EXTENSION_DIR': `${TMP_DIR}/${TMP_EXT_DIR}`,
        }
      );

      const jsonContent = await sshHelper.executeCommandWithNoError(`_BPXK_AUTOCVT=ON cat ${component_instance_dir}/.manifest.json`);
      expect(jsonContent).to.be.equal(`{\n  "name": "${dummy_component_name}"\n}`);
    });

  });

  const process_component_apiml_static_definitions = 'process_component_apiml_static_definitions';
  describe(`verify ${process_component_apiml_static_definitions}`, function() {
    const static_def_file = 'static-def.yaml';
    // this may change in the future
    const static_def_dir = `${process.env.ZOWE_INSTANCE_DIR}/workspace/api-mediation/api-defs`;
    const target_static_def_file = `${dummy_component_name}_static_def_yaml.yml`;

    before('create test component', async function() {
      await sshHelper.executeCommandWithNoError(`rm -rf ${component_runtime_dir} && mkdir -p ${component_runtime_dir} && echo 'name: ${dummy_component_name}\napimlServices:\n  static:\n  - file: ${static_def_file}' > ${component_runtime_dir}/manifest.yaml && echo 'services: does not matter' > ${component_runtime_dir}/${static_def_file}`);
    });

    after('dispose test component', async function() {
      await sshHelper.executeCommandWithNoError(`rm -rf ${component_runtime_dir} && rm -fr ${static_def_dir}/${target_static_def_file}`);
    });

    it('test processing APIML static definitions', async function() {
      await test_component_function_has_expected_rc_stdout_stderr(
        `${process_component_apiml_static_definitions} "${component_runtime_dir}"`,
        {
          'ZWE_EXTENSION_DIR': `${TMP_DIR}/${TMP_EXT_DIR}`,
        },
        {
          stdout: `process ${dummy_component_name} service static definition file ${static_def_file} ...`
        }
      );

      const jsonContent = await sshHelper.executeCommandWithNoError(`_BPXK_AUTOCVT=ON iconv -f IBM-850 -t IBM-1047 ${static_def_dir}/${target_static_def_file}`);
      expect(jsonContent).to.be.equal('services: does not matter');
    });

  });

  const process_component_desktop_iframe_plugin = 'process_component_desktop_iframe_plugin';
  describe(`verify ${process_component_desktop_iframe_plugin}`, function() {
    const dummy_component_title = 'Sanity Test Dummy';
    const dummy_component_id = 'org.zowe.plugins.sanity_test_dummy';
    const dummy_component_url = '/ui/v1/dummy';
    const component_instance_dir = `${process.env.ZOWE_INSTANCE_DIR}/workspace/${dummy_component_name}`;
    const app_server_plugins_dir = `${process.env.ZOWE_INSTANCE_DIR}/workspace/app-server/plugins`;

    before('create test component', async function() {
      await sshHelper.executeCommandWithNoError(`rm -rf ${component_runtime_dir} && mkdir -p ${component_runtime_dir} && rm -fr ${component_instance_dir} && echo 'name: ${dummy_component_name}\nid: ${dummy_component_id}\ntitle: ${dummy_component_title}\ndesktopIframePlugins:\n- url: ${dummy_component_url}\n  icon: image.png' > ${component_runtime_dir}/manifest.yaml && echo 'dummy' > ${component_runtime_dir}/image.png`);
    });

    after('dispose test component', async function() {
      await sshHelper.executeCommandWithNoError(`rm -rf ${component_runtime_dir} && rm -fr ${component_instance_dir} && rm -fr ${app_server_plugins_dir}/${dummy_component_id}.json`);
    });

    it('test processing Desktop iFrame plugins', async function() {
      await test_component_function_has_expected_rc_stdout_stderr(
        `${process_component_desktop_iframe_plugin} "${component_runtime_dir}"`,
        {
          'ZWE_EXTENSION_DIR': `${TMP_DIR}/${TMP_EXT_DIR}`,
        },
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
