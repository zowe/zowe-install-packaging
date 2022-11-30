/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import fs from 'fs'
import YAML from 'js-yaml'

var commandArgs = process.argv.slice(2);
if (commandArgs.lenght != 2) {
  console.log("Usage: manifest.yaml-in-path package.json-out-path");
}

console.log("Reading for conversion yaml file "+commandArgs[0]);
const yamlIn = fs.readFileSync(commandArgs[0], 'utf8')
let yamlFile=YAML.load(yamlIn);


let packageJson = {
  name: yamlFile.name,
  version: yamlFile.version,
  description: yamlFile.description,
  homepage: yamlFile.homepage,
  keywords: yamlFile.keywords,
  license: yamlFile.license,
  repository: yamlFile.repository
};

fs.writeFileSync(commandArgs[1], JSON.stringify(packageJson, null, 2));
console.log("Wrote to "+commandArgs[1]);
console.log('\nZowe npm components can be published as either an archive of the component or a directory of the component');
console.log('To publish an archive, define its path in the "main" property of package.json');
console.log('If publishing a component for z/OS, it is recommended to ship a pax archive with tagged content.');
console.log('When uploading to npm, ensure the pax archive is tagged as binary');