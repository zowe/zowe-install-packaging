const path = require('path');
const fs = require('fs-extra');
const cp = require('child_process');
const YAML = require('js-yaml');
const rimraf = require('rimraf');
const { default: Ajv } = require('ajv/dist/2019');
const velocity = require('velocityjs');
const unescapeJs = require('unescape-js');

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

//// ---- init section -----
// we collect all errors before quitting out
const errors = [];
const LOCAL_TEMP_DIR = path.resolve(__dirname, 'tmp');
const ERROR_CASES_DIR = path.resolve(LOCAL_TEMP_DIR, 'collected_errors');

// required method implementations for velocity-js
const velocityMethodHandlers = [
  {
    uid: 'trim',
    match: (payload) => {
      return payload.property === 'trim';
    },
    resolve: (payload) => {
      return payload.context.toString().trim()
    }
  }, 
  {
    uid: 'length',
    match: (payload) => {
      return payload.property === 'length';
    },
    resolve: (payload) => {
      return payload.context.toString().length;
    }
  }, 
  {
    uid: 'includes',
    match: (payload) => {
      return payload.property === 'includes';
    },
    resolve: (payload) => {
      if (payload.params.length > 1) {
        return false;
      }
      const includeTerm = unescapeJs(payload.params[0]);
      if (payload.context.toString().includes(includeTerm)) {
        return 1;
      } 
      return -1; //explicitly -1, returning 'includes' result coerces result to a bool which breaks template 
    }
  }, 
  {
    uid: 'split',
    match: (payload) => {
      return payload.property === 'split';
    },
    resolve: (payload) => {
      if (payload.params.length > 1) {
        return payload.context.toString();
      }
      const splitTerm = unescapeJs(payload.params[0].toString());
      return payload.context.toString().split(splitTerm)
    }
  }
];

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
fs.mkdirpSync(ERROR_CASES_DIR);

const SCHEMA_PATH = path.resolve(REPO_DIR, 'schemas');
const SCHEMA_SERVER_COMMON = path.resolve(SCHEMA_PATH, 'server-common.json');
const SCHEMA_ZOWE_YAML = path.resolve(SCHEMA_PATH, 'zowe-yaml-schema.json');

// Setup Workflow YAML variables and local files
let WF_PROPERTIES_COMMON_BASE = {};
const WF_DIR = path.resolve(REPO_DIR, 'workflows');
const ZWECONF_WF_FILE_PATH = path.resolve(WF_DIR, 'files', 'ZWECONF.xml');
const ZWECONF_SH_TEMPLATE = path.resolve(LOCAL_TEMP_DIR, 'zowe.yaml.ZWECONF.sh');
const ZWEAMLCF_WF_FILE_PATH = path.resolve(WF_DIR, 'files', 'ZWEAMLCF.xml');
const ZWEAMLCF_SH_TEMPLATE = path.resolve(LOCAL_TEMP_DIR, 'zowe.yaml.ZWEAMLCF.sh');

// shared properties between ZWEAMLCF and ZWECONF
const ZWECONF_PROPERTIES_FILE_PATH = path.resolve(WF_DIR, 'files', 'ZWECONF.properties');
let wf_conf_properties = fs.readFileSync(ZWECONF_PROPERTIES_FILE_PATH, 'utf8');
wf_conf_properties = wf_conf_properties.replaceAll(/#(.*)$\n/gm, '');
for (let line of wf_conf_properties.split('\n')) {
  if (line.trim().length > 0) {
    let propSplit = line.split('=');
    let key = propSplit[0];
    let value = propSplit[1];
    WF_PROPERTIES_COMMON_BASE[key] = value;
  }
}
WF_PROPERTIES_COMMON_BASE['zowe_runtimeDirectory'] = path.resolve(LOCAL_TEMP_DIR, 'test_yaml');
WF_PROPERTIES_COMMON_BASE['zowe_workspaceDirectory'] = path.resolve(LOCAL_TEMP_DIR, 'test_yaml');
Object.freeze(WF_PROPERTIES_COMMON_BASE); // Protect Base config
fs.writeFileSync(path.resolve(LOCAL_TEMP_DIR, 'zowe.base.properties.yaml'), YAML.dump(WF_PROPERTIES_COMMON_BASE), { mode: 0o766 });

// Define workflows to test, initialize them and use them with test cases
const workflowsToTest = [
  {
    name: 'ZWECONF',
    content: '',
    filePath: ZWECONF_WF_FILE_PATH,
    templatePath: ZWECONF_SH_TEMPLATE
  }, {
    name: 'ZWEAMLCF',
    content: '',
    filePath: ZWEAMLCF_WF_FILE_PATH,
    templatePath: ZWEAMLCF_SH_TEMPLATE
  }
]

for (const wf of workflowsToTest) {
  wf.content = fs.readFileSync(wf.filePath).toString();
  wf.content = wf.content.split('<inlineTemplate substitution="true"><![CDATA[')[1];
  wf.content = wf.content.split(']]></inlineTemplate>')[0];
  wf.content = wf.content.replaceAll('set -x', '');
  wf.content = wf.content.replaceAll('set -e', '');
  wf.content = wf.content.replaceAll('instance-', '');
  wf.content = wf.content.replaceAll('global-', '');
  wf.content = wf.content.replace(/^zwe.*$/m, '');
  fs.writeFileSync(wf.templatePath, wf.content);

}


// Setup AJV Parser
let ajvParser;
const ajv = new Ajv({
  strict: "log",
  unicodeRegExp: false,
  allErrors: true
});
ajv.addSchema([fs.readJSONSync(SCHEMA_SERVER_COMMON)]);
ajv.addKeyword('$anchor');
ajvParser = ajv.compile(fs.readJsonSync(SCHEMA_ZOWE_YAML, 'utf8'));

///// --- end init section ----

/**
 *  Run a default schema validation (no custom variables)
 */
let testConfig = getBaseConf();
let testDir = path.resolve(LOCAL_TEMP_DIR, 'test_defaults');

const result = runSchemaValidation(testConfig, testDir, workflowsToTest[0]);
if (result.errors != null) {
  errors.push('There should be no errors for a default schema validation.');
}

/**
 *  Run coverage for all known permutations of zowe.yaml produced by config workflow.
 */

// Structure used to generate combinations of config choices. Complete combinations are only created for fields with dependentBranches.
//    The rest of the fields simply "fill-in" their values to existing permutations, ensuring their values are covered somewhere in a test case.
// (12 in total at writing)
// could we be smarter about this and auto-generate the fields in the future?
const configBranches = [
  { field: 'zowe_setup_jcl_header', values: [ '', 'abc', 123, 'this_is\nmultiline\nheader']},
  { field: 'zowe_externalDomains', values: ['localhost', 'localhost\nsome.other.host\n.dns.magic']},
  { field: 'zowe_setup_vsam_mode', values: ['NONRLS', 'RLS', ''] },
  { field: 'components_gateway_enabled', values: [true, false] },
  { field: 'components_zaas_enabled', values: [true, false] },
  { field: 'components_api_catalog_enabled', values: [true, false] },
  { field: 'components_discovery_enabled', values: [true, false] },
  { field: 'components_app_server_enabled', values: [true, false] },
  {
    field: 'components_zss_enabled', values: [true, false], dependentBranches: {
      when: true, branches: [
        { field: 'components_zss_agent_jwt_fallback', values: [true, false] }
      ]
    }
  },
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
  }
];


const testMatrix = generatePermutations(configBranches);
testDir = path.resolve(LOCAL_TEMP_DIR, 'test_permutations');
let testCt = 0;
// Run the tests. 
for (const [testIdx, test] of testMatrix.entries()) {
  
  testConfig = getBaseConf();

  for (const element of test) {
    const pieces = element.split('=');
    testConfig[pieces[0]] = '' + pieces[1];
  }

  for (const wf of workflowsToTest) {
    const result = runSchemaValidation(testConfig, testDir, wf);
    if (result.errors != null) {
      const testCase = test.map((t, i) => `\t${t}`).join('\n');
      errors.push(`There were errors during schema validation: ${JSON.stringify(result.errors, { indent: 2 })}.\n\n Supplied config:\n ${testCase}\n`);
      fs.copySync(path.resolve(testDir, 'zowe.test.properties.yaml'), path.resolve(ERROR_CASES_DIR, `zowe.yaml.properties.${testIdx}`))
      fs.readdirSync(testDir).filter((file) => /zowe\.([^..]*?)\.yaml/mi.test(file)).forEach((zoweYamlTest) => {
        fs.copySync(path.resolve(testDir, zoweYamlTest), path.resolve(ERROR_CASES_DIR, `${zoweYamlTest}.${testIdx}`))
      })
    }
    testCt++;
  }
}

console.log(`${testCt} tests run.`);

if (errors.length > 0) {
  console.log(errors.join('\n'));
  process.exit(1);
}

process.exit(0);


function getBaseConf() {
  return JSON.parse(JSON.stringify(WF_PROPERTIES_COMMON_BASE));
}

// Generates permutations by recursing all the way down the item array, and building up by concatenating results.
//  will multiply (combining permutations) when dependentBranches exist, otherwise return arrays as-is with new values prepended.
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
        // multiply existing arrays * extraPermutations. (2 existing, 3 new = 6 total arrays)
        merged.forEach((a) => { extraPermutations.forEach((b) => newPerms.push(a.concat(b))); });
        merged = newPerms; 
      }
      perms.push(...merged);
    }
  } else {
    // ensure we have enough arrays to concat at least one of every `currItem.values` options. Duplicating existing subPerms is fine.
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


function runSchemaValidation(testConfig, testDir, workflow) {
  fs.mkdirpSync(testDir);

  const yamlPath = renderTemplate(testConfig, testDir, workflow);
  const zoweYaml = YAML.load(fs.readFileSync(yamlPath, 'utf8'));
  const validation = ajvParser(zoweYaml);
  return { res: validation, errors: ajvParser.errors };
}

function renderTemplate(testConfig, testDir, workflow) {
  fs.mkdirpSync(testDir);
  const yamlPropertiesFile = path.resolve(testDir, 'zowe.test.properties.yaml');
  testConfig['zowe_runtimeDirectory'] = testDir;
  testConfig['zowe_workspaceDirectory'] = testDir;
  fs.writeFileSync(yamlPropertiesFile, YAML.dump(testConfig), { mode: 0o766 });
  const zoweYmlScriptOut = path.resolve(testDir, `zowe.yaml.final.${workflow.name}.sh`);
  const renderContent = velocity.render(fs.readFileSync(workflow.templatePath, 'utf8'), testConfig, null, {
    customMethodHandlers: velocityMethodHandlers
  });
  fs.writeFileSync(zoweYmlScriptOut, renderContent, { mode: 0o755 });
  cp.execSync(`${zoweYmlScriptOut}`);
  const zoweYamlOut = path.resolve(testDir, `zowe.${workflow.name}.yaml`);
  fs.moveSync(path.resolve(testDir, 'zowe.yaml'), zoweYamlOut, {overwrite: true})
  return zoweYamlOut;
}

