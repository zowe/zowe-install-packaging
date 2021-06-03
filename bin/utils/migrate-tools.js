/*
  This program and the accompanying materials are
  made available under the terms of the Eclipse Public License v2.0 which accompanies
  this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
  
  SPDX-License-Identifier: EPL-2.0
  
  Copyright Contributors to the Zowe Project.
*/

const fs = require('fs');
const path = require('path');
const os = require('os');
const isZos = os.platform() == 'os390';


const types = {
  "zos": 1,
  //aliases since there is uncertainty about zcx being independent or just "container"
  "container": 2,
  "docker": 2,
  "kubernetes": 2,
  "docker-bundle": 3
};

const TYPE_ZOS=1;
const TYPE_CONTAINER=2;
const TYPE_CONTAINER_BUNDLE=3;

const commandArgs = process.argv.slice(2);
if (commandArgs.length != 4) {
  console.error(`Usage: Run this from zowe-migrate-instance.sh`);
  process.exit(1);
}

const instanceDir = commandArgs[0];
const outputDir = commandArgs[1];
const toType = commandArgs[2];
const fromType = commandArgs[3];

if (!process.env['KEYSTORE_TYPE']) {
  console.error(`Could not read KEYSTORE_TYPE env var. Env vars not set correctly for migration tool.`);
  process.exit(1);
}

const WORKSPACE_DIR = path.join(instanceDir, 'workspace');
const KEYSTORE_ENV_FILE = path.join(process.env['KEYSTORE_DIRECTORY'], 'zowe-certificates.env');


if (toType == fromType) {
  //this may be used to copy-paste duplicate instances in the future?
  console.error(`Error: same type migration not yet implemented`);
  process.exit(2);
}

if (toType == TYPE_ZOS && fromType == TYPE_CONTAINER) {
  migrateZosContainer();
} else if (toType == TYPE_ZOS && fromType == TYPE_CONTAINER_BUNDLE) {
  migrateZosBundle();
} else if (toType == TYPE_CONTAINER && fromType == TYPE_ZOS) {
  migrateContainerZos();
} else if (toType == TYPE_CONTAINER_BUNDLE && fromType == TYPE_ZOS) {
  migrateBundleZos();
} else if (toType == TYPE_CONTAINER_BUNDLE && fromType == TYPE_CONTAINER) {
  migrateBundleContainer();
} else if (toType == TYPE_CONTAINER && fromType == TYPE_CONTAINER_BUNDLE) {
  migrateContainerBundle();
} else {
  console.error(`Error: unimplemented migration from ${fromType} to ${toType}`);
  process.exit(3);
}

function migrateZosContainer() {
  console.error('nyi migrateZosContainer');
  process.exit(1);
}
function migrateContainerZos() {
  console.error('nyi migrateContainerZos');
  process.exit(1);
}
function migrateBundleContainer() {
  console.error(`nyi migrateBundleContainer`);
  process.exit(1);
}
function migrateContainerBundle() {
  console.error(`nyi migrateContainerBundle`);
  process.exit(1);
}

//ebcic -> ascii, keyring check (no support), path updating
function migrateZosBundle() {
  migrateKeystoreZosBundle();

  if (isZos) {
    //simple conversion: reading files and writing them will do ebcdic-ascii conversion automatically!
    convertRecursively(path.join(instanceDir, 'workspace'), path.join(outputDir, 'instance', 'workspace', undefined));
  } else {
    //no tagging info, this is going to be guesswork.
    console.error(`Error: Cannot migrate z/OS instance while not on z/OS. Rerun this script on z/OS.`);
    process.exit(4);
  }
}

//ascii -> ebcdic, path updating
function migrateBundleZos() {
  console.error(`nyi migrateBundleZos`);
  process.exit(1);
  /*
  migrateKeystore();
  migrateConfigZosBundle();

  if (isZos) {
    //everything is ascii, so try run tag-files.sh?
    migrateWorkspace();
  } else {
    //TODO manual conversion based on extension and possible overrides
  }
  */
}

function canMigrateKeystore() {
  return process.env['KEYSTORE_TYPE'] == "PKCS12";
}

function migrateKeystoreZosBundle() {
  // ----- at beginning of file is a really good clue this is a text file
  //zowe-certificates.env
  if (!canMigrateKeystore()) {
    console.error(`Keystore type ${process.env['KEYSTORE_TYPE']} is not supported for migration`);
    process.exit(1);
  }
  fs.readFileSync(KEYSTORE_ENV_FILE,
  convertRecursively(process.env['KEYSTORE_DIRECTORY'], path.join(outputDir, 'instance', ), undefined, WORKSPACE_DIR, certConvert);
}

function migrateConfigZosBundle() {
  //migrate instance minus workspace
  convertRecursively(instanceDir, path.join(outputDir, 'instance'), undefined, WORKSPACE_DIR, simpleConvert);
  setDockerInstancePaths();
}

const INSTANCE_PATHS = {
  'ROOT_DIR': "/home/zowe/install",
  'JAVA_HOME': "/usr/local/openjdk-8",
  'NODE_HOME':'/usr/local/node',
  'KEYSTORE_DIRECTORY': "/home/zowe/certs"
}

function setDockerInstancePaths() {
  let instance = fs.readFileSync(path.join(outputDir, 'instance', 'instance.env'), 'utf8');
  let lines = instance.split('\n');
  const paths = Object.keys(INSTANCE_PATHS);
  for (let i = 0; i < lines.length; i++) {
    let line = lines[i].trim();
    paths.forEach((path)=> {
      if (line.startsWith(path+'=')) {
        line = path+'='+INSTANCE_PATHS[path];
      }
    });
  }
  instance = lines.join('\n');
  fs.writeFileSync(path.join(outputDir, 'instance', 'instance.env'));
}


function certConvert(fullPath, destinationPath, convertMap) {
  const buff = fs.readFileSync(fullPath);
  if (fullPath.endsWith('.p12')){ //p12 is binary, dont convert
    //copy
    fs.writeFileSync(destinationPath, buff);
  } else {
    const char = buff[0];
    //look for -----
    if (buff.length > 5 && (buff[0] == buff[1] == buff[2] == buff[3] == buff[4]) && (char == 0x60 || char == 0x2d)) {
      //likely to be a text file cert or key
      if (!convertMap) {
        fs.writeFileSync(destinationPath, fs.readFileSync(fullPath, 'utf8'));
      } else {
        const content = fs.readFileSync(fullPath);
        for (let i = 0; i < content.length; i++) {
          content[i] = convertMap[i];
        }
        fs.writeFileSync(destinationPath, content);
      }
    } else { //i guess its binary
      console.warn(`file '${fullPath}' not identified as text. first char=${char}`);
      fs.writeFileSync(destinationPath, buff);
    }
    
  }
}

function simpleConvert(fullPath, destinationPath, convertMap) {
  if (!convertMap) {
    //TODO make more efficient by streaming buffer
    fs.writeFileSync(destinationPath, fs.readFileSync(fullPath, 'utf8'));
  } else {
    const content = fs.readFileSync(fullPath);
    for (let i = 0; i < content.length; i++) {
      content[i] = convertMap[i];
    }
    fs.writeFileSync(destinationPath, content);
  }
}

//if convertMap is null, we use nodejs string conversion trick of zos to input ??? and output ascii
//TODO make async
function convertRecursively(inputPath, outputPath, convertMap, ignorePath, convertFunction) {
  fs.mkdirSync(outputPath);
  const names = fs.readdirSync(inputPath);
  names.forEach(function(name) {
    const fullPath = path.join(inputPath, name);
    const destinationPath = path.join(outputPath, name);
    if (fullPath != ignorePath) {
      const stat = fs.statSync(fullPath);
      if (stat.isDirectory()) {
        fs.mkdirSync(destinationPath);
        convertRecursively(fullPath, destinationPath, convertMap, ignorePath);
      } else {
        convertFunction(fullPath, destinationPath, convertMap);
      }
    }
  });
}
