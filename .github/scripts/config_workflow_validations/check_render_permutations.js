const path = require('path');
const fs = require('fs-extra');
const cp = require('child_process');
const YAML = require('js-yaml');
const rimraf = require('rimraf');
const { default: Ajv } = require('ajv/dist/2019');
const velocity = require('velocityjs');

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
  REPO_DIR += '../';
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
let testDir = path.resolve(LOCAL_TEMP_DIR, 'test_defaults');

const result = runSchemaValidation(testConfig, testDir);
if (result.errors != null) {
  errors.push('There should be no errors for a default schema validation.');
}

// represent combinations of config paths, even unrelated ones
// (1152 in total at writing)
// could we be smarter about this and auto-generate the fields in the future?
//  should we mark isolated config options to reduce permutation count?
const configBranches = [
  { field: 'zowe_setup_vsam_mode', values: ['NONRLS', 'RLS', ''] },
  { field: 'components_gateway_enabled', values: [true, false] },
  { field: 'components_zaas_enabled', values: [true, false] },
  { field: 'components_api_catalog_enabled', values: [true, false] },
  { field: 'components_discovery_enabled', values: [true, false] },
  {
    field: 'components_caching_service_enabled', values: [true, false], dependentBranches:
    {
      when: true, branches: [
        {
          field: 'components_caching_service_storage_mode', values: ['infinispan', 'VSAM'], dependentBranches: {
            when: 'infinispan', branches: [
              { field: 'components_caching_service_storage_infinispan_jgroups_host', values: ["", 'localhost'] }
            ]
          }
        }
      ]
    }
  },
  { field: 'components_app_server_enabled', values: [true, false] },
  {
    field: 'components_zss_enabled', values: [true, false], dependentBranches: {
      when: true, branches: [
        { field: 'components_zss_agent_jwt_fallback', values: [true, false] }
      ]
    }
  }
];

testConfig = getBaseConf();

const testMatrix = generatePermutations(configBranches);
testDir = path.resolve(LOCAL_TEMP_DIR, 'test_permutations');
for (const test of testMatrix) {
  for (let i = 0; i < configBranches.length; i++) {
    const pieces = test[i].split('=');
    testConfig[pieces[0]] = '' + pieces[1];
  }

  const result = runSchemaValidation(testConfig, testDir);
  if (result.errors != null) {
    const testCase = test.map((t, i) => `\t${configBranches[i]} = ${t}`).join('\n');
    errors.push(`There were errors during schema validation: ${JSON.stringify(result.errors, { indent: 2 })}.\n\n Supplied config:\n ${testCase}\n`);
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
function generatePermutations(items) {
  if (items == null || items.length == 0) {
    return [[]];
  }
  const subPermutations = generatePermutations(items.slice(1));
  
  const currItem = items[0];
  const perms = [];
  for (const val of currItem.values) {
    let merged = subPermutations.map(function (arr) {
      return [`${currItem.field}=${val}`].concat(arr);  
    })

    if (currItem.dependentBranches && currItem.dependentBranches.when === val) {
      const extraPermutations = generatePermutations(currItem.dependentBranches.branches);
      const newPerms = [];
      merged.forEach((a) => { extraPermutations.forEach((b) => newPerms.push(a.concat(b))); });
      merged = newPerms;
    }

    perms.push(...merged);
  }

  return perms;
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
  fs.writeFileSync(zoweYmlScriptOut, renderContent, { mode: 0o755 });
  cp.execSync(`${zoweYmlScriptOut}`);
  return path.resolve(testDir, 'zowe.yaml');
}

