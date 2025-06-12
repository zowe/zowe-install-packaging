const fs = require('fs-extra');
const path = require('path');
const yaml = require('js-yaml');
const _ = require('lodash');

/**
 *   Run tests which verify the variables defined in ZWECONF.xml and ZWEAMLCF.xml are in sync with fields defined
 *     in example-zowe.yaml and defaults.yaml. 
 * 
 *   If fields are missing from either the configuration workflows, or exist in the workflows and are missing from either 
 *     zowe.yaml file, this test will throw an error.
 *   
 *   Workflows are not expected to define fields 1:1 with zowe.yaml files, opting for sensible defaults in some cases. 
 *     To track known exceptions, 'zowe-yaml-sync-rules.json' is tracked under the 'workflows' folder in this repository.
 * 
 *   This test also checks that variables defined in ZWECONF.properties exist in ZWECONF.xml
 */

let REPO_DIR = process.cwd();
let backtrackCt = 0;

while (path.basename(path.resolve(REPO_DIR)) !== 'zowe-install-packaging') {
  REPO_DIR+='../';
  if (backtrackCt++ > 10) {
    throw new Error('Cannot find the root zowe-install-packaging directory.');
  }
}

const ROOT_REPO_DIR = REPO_DIR;
const SYNCFILE_PATH = path.resolve(ROOT_REPO_DIR, 'workflows', 'zowe-yaml-sync-rules.json');
const ZOWE_CFG_WORKFLOW_PATH = path.resolve(ROOT_REPO_DIR, 'workflows', 'files', 'ZWECONF.xml');
const ZOWE_CFG_PROPERTIES_PATH = path.resolve(ROOT_REPO_DIR, 'workflows', 'files', 'ZWECONF.properties');
const APIML_CFG_WORKFLOW_PATH = path.resolve(ROOT_REPO_DIR, 'workflows', 'files', 'ZWEAMLCF.xml');
const errors = [];

let SYNC_RULES = {};
if (fs.existsSync(SYNCFILE_PATH))  {
  SYNC_RULES = fs.readJSONSync(SYNCFILE_PATH);
}

const zoweYaml = yaml.load(fs.readFileSync(path.resolve(ROOT_REPO_DIR, 'example-zowe.yaml'), 'utf8'));
const defaultsYaml = yaml.load(fs.readFileSync(path.resolve(ROOT_REPO_DIR, 'files', 'defaults.yaml'), 'utf8'));
const flatZoweYamlVars = _.uniq(flatten(zoweYaml));
const flatDefaultsYamlVars = _.uniq(flatten(defaultsYaml));


for (const wf of [{cfg: ZOWE_CFG_WORKFLOW_PATH, props: ZOWE_CFG_PROPERTIES_PATH}, {cfg: APIML_CFG_WORKFLOW_PATH, props: ZOWE_CFG_PROPERTIES_PATH}]) {
  const workflowContent = fs.readFileSync(wf.cfg, 'utf8');
  const propsContent = fs.readFileSync(wf.props, 'utf8');
  const confMatches = workflowContent.matchAll(/^.*?variableValue name="(.*?)".*$/gmi);
  const propsMatches = propsContent.matchAll(/^([^#].*?)=(.*?)$/gmi);
  const confVars = new Set();
  const propsVars = new Set();
  for (const match of confMatches) {
    confVars.add(match[1]);
  }
  for (const match of propsMatches) {
    propsVars.add(match[1]);
  }

  // check that all propsVars exist in confVars
  const missingPropsInWf = _.differenceWith(confVars, propsVars);
  if (missingPropsInWf.length > 0) {
    errors.push(`Missing variables in ${path.basename(wf.props)} which are defined in ${path.basename(wf.cfg)}.\n\tList: \n\t\t${missingPropsInWf.join('\n\t\t')}`)
  }  

  diffWfAgainstZoweYaml(flatZoweYamlVars, flatDefaultsYamlVars, Array.from(confVars), path.basename(wf.cfg));
  diffZoweYamlAgainstWf(flatZoweYamlVars, flatDefaultsYamlVars, Array.from(confVars), path.basename(wf.cfg));
}

if (errors.length > 0) {
  console.log(`Errors detected:\n\n${errors.join('\n\n')}`)
  process.exit(1);
}


/** Checks for variables in zowe.yaml + defaults.yaml but not in given workflow */
function diffZoweYamlAgainstWf(zoweVars, defaultsVars, confVars, wfName) {
  const diff1 = _.differenceWith(_.uniq([...zoweVars, ...defaultsVars]), confVars)
  const wfDiffRules = SYNC_RULES.rules.filter((item) => (item.rule_target === 'all' || wfName.includes(item.rule_target)) && item.rule_type === 'wf_missing_vars').reduce((p, c) => {p.push(...c.rule_entry); return p;}, []);
  const finalDiff = _.differenceWith(diff1, wfDiffRules)
  if (finalDiff.length > 0) {
    errors.push(`Missing variables expected in ${wfName} which are defined in zowe.yaml or defaults.yaml.\n\tList: \n\t\t${finalDiff.join('\n\t\t')}`)
  }
}

/** Checks for variables in configuration workflows not present in zowe.yaml + defaults.yaml */
function diffWfAgainstZoweYaml(zoweVars, defaultsVars, confVars, wfName) {
  const diff1 = _.differenceWith(confVars, zoweVars)
  const diff2 = _.differenceWith(diff1, defaultsVars)
  const wfDiffRules = SYNC_RULES.rules.filter((item) => (item.rule_target === 'all' || wfName.includes(item.rule_target)) && item.rule_type === 'wf_extra_vars').reduce((p, c) => {p.push(...c.rule_entry); return p;}, []);
  const finalDiff = _.differenceWith(diff2,wfDiffRules)
  if (finalDiff.length > 0) {
    errors.push(`Unexpected variables found in ${wfName} which are not matched with fields in zowe.yaml.\n\tList: \n\t\t${finalDiff.join('\n\t\t')}`)
  }
}

/**
 * Flattens a json object, with nested keys separated by underscore, and hyphenated keys translated to underscores.
 * 
 * @param {*} jsonObj 
 * @returns 
 */
function flatten(jsonObj) {
  const flattened = [];
  for (const k of Object.keys(jsonObj))
    if (typeof jsonObj[k] === 'object' && jsonObj[k]!== null && !Array.isArray(jsonObj[k])) {
      flatten(jsonObj[k]).forEach((item) => {
        flattened.push(`${k.replaceAll('-', '_')}_${item}`);
      })
    } else {
      flattened.push(k.replaceAll('-', '_'));
    }
  return flattened;
}

