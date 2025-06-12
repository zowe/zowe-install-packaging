const path = require('path');
const fs = require('fs-extra');
const cp = require('child_process');
const YAML = require('js-yaml');
const rimraf = require('rimraf');
const { default: Ajv } = require('ajv/dist/2019');
const velocity = require('velocityjs');

/** 
*  Runs tests which verify the current Zowe schema works against the zowe.yaml
*    generated in configuration workflows. This creates a test matrix covering different combinations of
*    variable substitution to cover branching paths.
*
*    These tests should break when a change is introduced to schema, or the config workflow zowe.yaml contents.
*
*  Note: this does not create a merged YAML with defaults.yaml. 
*    It is possible for configmgr-specific bugs to exist that won't be caught here.
*    It is possible for schema failures to occur if fields are required and only present in defaults.yaml
*/

// collect all errors before quitting out
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
 *  Run a default schema validation (no custom variables)
 */
let testConfig = getBaseConf();
let testDir = path.resolve(LOCAL_TEMP_DIR, 'test_defaults');

const result = runSchemaValidation(testConfig, testDir);
if (result.errors != null) {
  errors.push('There should be no errors for a default schema validation.');
}

/**
 *  Run coverage for all known permutations of zowe.yaml produced by config workflow.
 */

// Structure used to generate combinations of config choices. Complete permutations are only created for fields with dependentBranches.
//    The rest of the fields simply "fill-in" their values to existing permutations, ensuring their values are covered somewhere in a test case.
// (12 in total at writing)
// could we be smarter about this and auto-generate the fields in the future?
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
testDir = path.resolve(LOCAL_TEMP_DIR, 'test_permutations');

const testMatrix = generatePermutations(configBranches);

// Run the test
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
  console.log(errors.join('\n'));
  process.exit(1);
}

process.exit(0);


function getBaseConf() {
  return JSON.parse(JSON.stringify(WF_CONF_YAML_BASE));
}

// Generates permutations by recursing all the way down the item array, and building up by concatenating results.
//  will multiply (combining permutations) when dependentBranches exist, otherwise linearly return arrays with new values prepended.
function generatePermutations(items) {
  if (items == null || items.length == 0) {
    return [[]];
  }
  const subPermutations = generatePermutations(items.slice(1));
  const currItem = items[0];
  const perms = [];
  if (currItem.dependentBranches) {
    for (const val of currItem.values) {
      let merged = [];
      merged =subPermutations.map(function (arr) {
        return [`${currItem.field}=${val}`].concat(arr);  
      })

      if (currItem.dependentBranches.when === val) {
        const extraPermutations = generatePermutations(currItem.dependentBranches.branches);
        const newPerms = [];
        // multiples each existing array * extraPermutations. (2 existing, 3 new = 6 total arrays)
        merged.forEach((a) => { extraPermutations.forEach((b) => newPerms.push(a.concat(b))); });
        merged = newPerms; 
      }
      perms.push(...merged);
    }
  } else {
    // since we don't iterate over currItem.values, ensure we have enough arrays to concat in below map. Just duplicate existing is fine.
    while (subPermutations.length < currItem.values.length) {
      subPermutations.push(subPermutations[0]);
    }
    // concat and randomly rotate through currItem values
    let merged = subPermutations.map((arr, i) => {
      const useVal = currItem.values[i%currItem.values.length];
      return [`${currItem.field}=${useVal}`].concat(arr);
    })
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

