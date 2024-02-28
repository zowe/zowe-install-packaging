const path = require('path');
const fs = require('fs-extra');
const cp = require('child_process');
const { LOCAL_TEMP_DIR } = require('../constants');
const YAML = require('yaml');
const rimraf = require('rimraf');
const { default: Ajv } = require('ajv/dist/2019');
const {assert, expect  }= require('chai');
const velocity = require('velocityjs');


/* 
  Runs tests which verify the current Zowe schema works against the zowe.yaml
    provided in the PSWI workflows. Different tests cover different combinations of
    variable substitution to cover branching paths.

    Test is self-contained; i.e. all initialization of pre-reqs done in the before() method.

    Test should break when either the (a) schema changes or (b) pswi zowe.yaml schemas.
*/
describe('verify pswi zowe.yaml is consistent with rest of zowe', function(){

  rimraf.sync(LOCAL_TEMP_DIR);
  fs.mkdirSync(LOCAL_TEMP_DIR);
  const SCHEMA_PATH = path.resolve('..', '..', 'schemas');
  const SCHEMA_SERVER_COMMON = path.resolve(SCHEMA_PATH, 'server-common.json');
  const SCHEMA_ZOWE_YAML = path.resolve(SCHEMA_PATH, 'zowe-yaml-schema.json');
  /* const VTL_DIR = path.resolve(LOCAL_TEMP_DIR, 'vtl');
  const VTL_BIN = path.resolve(VTL_DIR, 'vtl');
  const VTL_CLI_TAR_URL = 'https://github.com/zowe/vtl-cli/releases/download/v1.0.6/vtl.tar.gz';*/
  const ZOWE_YAML_SH_TEMPLATE = path.resolve(LOCAL_TEMP_DIR, 'zowe.yaml.sh');
  let WF_DIR = null;
  let WF_CONF_YAML_BASE = {}; // do not modify directly, use "getConfBase"
  let WF_SCRIPT = path.resolve(LOCAL_TEMP_DIR, 'zowe.yaml.sh');
  let ajvParser;

  before('setup test pre-reqs', async function() {
    // Setup Workflow YAML variables and local files
    let wf_conf_properties;
    let PSWI_CONF = '';
    let currentPath = process.cwd();
    while (WF_DIR == null) {
      let dirContents = fs.readdirSync(currentPath);
      if (dirContents.includes('workflows')) {
        WF_DIR = path.resolve(currentPath, 'workflows');
      }
      currentPath = path.resolve(currentPath, '..');
    }
    PSWI_CONF = fs.readFileSync(path.resolve(WF_DIR, 'files', 'ZWECONF.xml')).toString();
    wf_conf_properties = fs.readFileSync(path.resolve(WF_DIR, 'files', 'ZWECONF.properties')).toString();
    PSWI_CONF = PSWI_CONF.split('<inlineTemplate substitution="true"><![CDATA[')[1];
    PSWI_CONF = PSWI_CONF.split(']]></inlineTemplate>')[0];
    PSWI_CONF = PSWI_CONF.replaceAll('set -x', '');
    PSWI_CONF = PSWI_CONF.replaceAll('set -e', '');
    PSWI_CONF = PSWI_CONF.replaceAll('instance-', '');

    wf_conf_properties = wf_conf_properties.replaceAll(/#(.*)$\n/gm, '');
    for (let line of wf_conf_properties.split('\n')) {
      if (line.trim().length > 0) {
        let propSplit = line.split('=');
        let key = propSplit[0];
        let value = propSplit[1];
        WF_CONF_YAML_BASE[key] = value;
      }
    }
    WF_CONF_YAML_BASE['zowe_runtimeDirectory'] = path.resolve(LOCAL_TEMP_DIR, 'test_yaml');
    fs.writeFileSync(path.resolve(LOCAL_TEMP_DIR, 'zowe.base.properties.yaml'), YAML.stringify(WF_CONF_YAML_BASE), { mode: 0o766 });
    fs.writeFileSync(WF_SCRIPT, PSWI_CONF, { mode: 0o755 });


    // Get VTL-CLI
    // Using velocityjs package to avoid JVM spinup, results are 1:1 with vtl cli
    /* 
    const vtlTar = path.resolve(LOCAL_TEMP_DIR, 'vtl-cli.tar.gz');
    const { data } = await request(VTL_CLI_TAR_URL);
    fs.writeFileSync(vtlTar, data);

    const extractPromise = new Promise((resolve) => {
      const str = fs.createReadStream(vtlTar).pipe(gunzip()).pipe(tar.extract(VTL_DIR));
      str.on('finish', resolve);
    });
    await extractPromise;*/

    // Setup AJV Parser
    const ajv = new Ajv({
      strict: 'false',
      unicodeRegExp: false,
      allErrors: true
    });
    ajv.addSchema([JSON.parse(fs.readFileSync(SCHEMA_SERVER_COMMON))]);
    ajv.addKeyword('$anchor');
    ajvParser = ajv.compile(JSON.parse(fs.readFileSync(SCHEMA_ZOWE_YAML)));

    // Protect Base config
    Object.freeze(WF_CONF_YAML_BASE);  // protect base configuration

  });

  /**
   * Attempts to find quote or type changes for individual fields
   */
  it('test field changes', function() {

  });

  it('known failures', function() {
    const testConfig = getBaseConf();
    const testDir = path.resolve(LOCAL_TEMP_DIR, 'wip_tests');

    const result = runSchemaValidation(testConfig, testDir);
    assert(result.errors != null, 'There should be errors during schema validation.');
    expect(result.res).to.be.false;
  });

  it('patched pass', function() {
    const testConfig = getBaseConf();
    const testDir = path.resolve(LOCAL_TEMP_DIR, 'wip_tests');

    // Known failures fixed:
    testConfig['java_home'] = '/usr/lpp/java/J8.0_64';
    testConfig['node_home'] = '/var/home/node/18';

    const result = runSchemaValidation(testConfig, testDir);
    assert(result.errors == null, `There were errors during schema validation: ${JSON.stringify(result.errors, {indent: 2})}`);
    expect(result.res).to.be.true;
  });

  it('branches with base config', function() {
    // represent simple if/else via true/false on each; no nested branches.
    const configBranches = [
      'components_gateway_enabled',
      'components_metrics_service_enabled',
      'components_api_catalog_enabled',
      'components_discovery_enabled',
      'components_caching_service_enabled',
      'components_app_server_enabled',
      'components_zss_enabled',
      'components_jobs_api_enabled',
      'components_files_api_enabled'
    ]; // all branch combos = 2^9 = 512

    const testConfig = getBaseConf();

    // Known failures fixed:
    testConfig['java_home'] = '/usr/lpp/java/J8.0_64';
    testConfig['node_home'] = '/var/home/node/18';

    const testMatrix = generateTrueFalsePermutations(configBranches.length);
    const testDir = path.resolve(LOCAL_TEMP_DIR, 'test_permutations');
    for (const test of testMatrix) {
      for (let i = 0; i < configBranches.length; i++) {
        testConfig[configBranches[i]] =  ''+test[i];
      }
      // later: collectot results
      const result = runSchemaValidation(testConfig, testDir);
      assert(result.errors == null, `There were errors during schema validation: ${JSON.stringify(result.errors, {indent: 2})}. Supplied config: ${test}`);
      expect(result.res).to.be.true;
    }

  });

  function getBaseConf() {
    return JSON.parse(JSON.stringify(WF_CONF_YAML_BASE));
  }

  // 
  function generateTrueFalsePermutations(itemCount) {
    if (itemCount == 0){ 
      return [[]];
    }
    const subPermutations = generateTrueFalsePermutations(itemCount-1);
    const zeroBase = subPermutations.map(function (arr) {
      return [false].concat(arr);
    });
    const oneBase = subPermutations.map(function (arr) {
      return [true].concat(arr);
    });
    
    return [...zeroBase, ...oneBase];
  }


  function runSchemaValidation(testConfig, testDir) {
    fs.mkdirpSync(testDir);
    const yamlPropertiesFile = path.resolve(testDir, 'zowe.test.properties.yaml');
    const zoweYmlScriptOut = path.resolve(testDir, 'zowe.yaml.final.sh');
    testConfig['zowe_runtimeDirectory'] = testDir;
    fs.writeFileSync(yamlPropertiesFile, YAML.stringify(testConfig), { mode: 0o766 });
   
    const renderContent = velocity.render(fs.readFileSync(ZOWE_YAML_SH_TEMPLATE, 'utf8'), testConfig);
    fs.writeFileSync(zoweYmlScriptOut, renderContent, {mode: 0o755 });
    cp.execSync(`${zoweYmlScriptOut}`);
    const zoweYaml = YAML.parse(fs.readFileSync(path.resolve(testDir, 'zowe.yaml'), 'utf8'));
    const validation = ajvParser(zoweYaml);
    return { res: validation, errors: ajvParser.errors };
  }

});
