const path = require('path');
const fs = require('fs-extra');
const cp = require('child_process');
const YAML = require('js-yaml');
const rimraf = require('rimraf');
const { default: Ajv } = require('ajv/dist/2019');
const velocity = require('velocityjs');
const {detailedDiff} = require('deep-object-diff');


/** 
*  Runs tests which verify the current Zowe schema works against the zowe.yaml
*    generated in configuration workflows. Different tests cover different combinations of
*    variable substitution to cover branching paths.
*    Test is self-contained; i.e. all initialization of pre-reqs done in the before() method.
*    Test should break when either the (a) schema changes or (b) pswi zowe.yaml schemas.
*
*  Note: this does not create a merged YAML with defaults.yaml. To test this with configmgr, 
*         write tests in zwe-remote-integration.
*/

const errors = [];
const LOCAL_TEMP_DIR = path.resolve(__dirname, 'tmp');
let REPO_DIR = process.cwd();
let backtrackCt = 0;

while (path.basename(path.resolve(REPO_DIR)) !== 'zowe-install-packaging') {
  REPO_DIR+='../';
  if (backtrackCt++ > 10) {
    throw new Error('Cannot find the root zowe-install-packaging directory.');
  }
}


rimraf.sync(LOCAL_TEMP_DIR);
fs.mkdirSync(LOCAL_TEMP_DIR);
const SCHEMA_PATH = path.resolve(REPO_DIR, 'schemas');
const SCHEMA_SERVER_COMMON = path.resolve(SCHEMA_PATH, 'server-common.json');
const SCHEMA_ZOWE_YAML = path.resolve(SCHEMA_PATH, 'zowe-yaml-schema.json');
const ZOWE_YAML_SH_TEMPLATE = path.resolve(LOCAL_TEMP_DIR, 'zowe.yaml.sh');
let WF_CONF_YAML_BASE = {}; // do not modify directly, use "getConfBase"
const WF_DIR = path.resolve(REPO_DIR, 'workflows');
let WF_SCRIPT = path.resolve(LOCAL_TEMP_DIR, 'zowe.yaml.sh');
let ajvParser;

// Setup Workflow YAML variables and local files
let wf_conf_properties;
let PSWI_CONF = '';
let currentPath = process.cwd();
PSWI_CONF = fs.readFileSync(path.resolve(WF_DIR, 'files', 'ZWECONF.xml')).toString();
wf_conf_properties = fs.readFileSync(path.resolve(WF_DIR, 'files', 'ZWECONF.properties')).toString();
PSWI_CONF = PSWI_CONF.split('<inlineTemplate substitution="true"><![CDATA[')[1];
PSWI_CONF = PSWI_CONF.split(']]></inlineTemplate>')[0];
PSWI_CONF = PSWI_CONF.replaceAll('set -x', '');
PSWI_CONF = PSWI_CONF.replaceAll('set -e', '');
PSWI_CONF = PSWI_CONF.replaceAll('instance-', '');
PSWI_CONF = PSWI_CONF.replace(/^zwe.*$/m, '');
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
fs.writeFileSync(path.resolve(LOCAL_TEMP_DIR, 'zowe.base.properties.yaml'), YAML.dump(WF_CONF_YAML_BASE), { mode: 0o766 });
fs.writeFileSync(WF_SCRIPT, PSWI_CONF, { mode: 0o755 });

// Setup AJV Parser
const ajv = new Ajv({
  strict: "log",
  unicodeRegExp: false,
  allErrors: true
});
ajv.addSchema([fs.readJSONSync(SCHEMA_SERVER_COMMON)]);
ajv.addKeyword('$anchor');
ajvParser = ajv.compile(fs.readJsonSync(SCHEMA_ZOWE_YAML, 'utf8'));

// Protect Base config
Object.freeze(WF_CONF_YAML_BASE);

/**
 * Attempts to find quote or type changes between examples-zowe and PSWI
 */
let testConfig = getBaseConf();
let testDir = path.resolve(LOCAL_TEMP_DIR, 'test_field_changes');

const wfYamlPath = renderYaml(testConfig, testDir);
const wfYamlContent = YAML.load(fs.readFileSync(wfYamlPath, 'utf8'));

const exampleZowePath = path.resolve(REPO_DIR,'example-zowe.yaml');
const exampleZoweYamlContent = YAML.load(fs.readFileSync(exampleZowePath, 'utf8'));

const result = runSchemaValidation(testConfig, testDir);
if(result.errors != null) {
  errors.push('There should be no errors for a default schema validation.');
}

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

testConfig = getBaseConf();

const testMatrix = generateTrueFalsePermutations(configBranches.length);
testDir = path.resolve(LOCAL_TEMP_DIR, 'test_permutations');
for (const test of testMatrix) {
  for (let i = 0; i < configBranches.length; i++) {
    testConfig[configBranches[i]] =  ''+test[i];
  }

  const result = runSchemaValidation(testConfig, testDir);
  if(result.errors != null){
    const testCase = test.map((t, i) => `\t${configBranches[i]} = ${t}`).join('\n');
    errors.push(`There were errors during schema validation: ${JSON.stringify(result.errors, {indent: 2})}.\n\n Supplied config:\n ${testCase}\n`);
  }
}

if (errors.length > 0) {
  console.log(errors.join('\n') + '\n');
  process.exit(1);
}

process.exit(0);


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

  const yamlPath = renderYaml(testConfig, testDir);
  const zoweYaml = YAML.load(fs.readFileSync(yamlPath, 'utf8'));
  const validation = ajvParser(zoweYaml);
  return { res: validation, errors: ajvParser.errors };
}

function renderYaml(testConfig, testDir) {
  fs.mkdirpSync(testDir);
  const yamlPropertiesFile = path.resolve(testDir, 'zowe.test.properties.yaml');
  testConfig['zowe_runtimeDirectory'] = testDir;
  fs.writeFileSync(yamlPropertiesFile, YAML.dump(testConfig), { mode: 0o766 });
  const zoweYmlScriptOut = path.resolve(testDir, 'zowe.yaml.final.sh');
  const renderContent = velocity.render(fs.readFileSync(ZOWE_YAML_SH_TEMPLATE, 'utf8'), testConfig);
  fs.writeFileSync(zoweYmlScriptOut, renderContent, {mode: 0o755 });
  cp.execSync(`${zoweYmlScriptOut}`);
  return path.resolve(testDir, 'zowe.yaml');
}

