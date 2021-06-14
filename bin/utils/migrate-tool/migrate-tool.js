/*
  This program and the accompanying materials are
  made available under the terms of the Eclipse Public License v2.0 which accompanies
  this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html

  SPDX-License-Identifier: EPL-2.0

  Copyright Contributors to the Zowe Project.
*/
console.log('js type='+process.env['KEYSTORE_TYPE']);
const { execSync } = require('child_process');
const fs = require('fs-extra');
const yaml = require('yaml');
const path = require('path');
const os = require('os');
const isZos = os.platform() == 'os390';

const TAG_FILES_LOCATION = '../../../scripts';

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
const toType = types[commandArgs[2]];
const fromType = types[commandArgs[3]];
console.log('keystore='+process.env['KEYSTORE_DIRECTORY']);

if (!process.env['KEYSTORE_TYPE']) {
  console.error(`Could not read KEYSTORE_TYPE env var. Env vars not set correctly for migration tool.`);
  process.exit(1);
}

const WORKSPACE_DIR = path.join(instanceDir, 'workspace');
console.log(`instance=${instanceDir}`);
console.log(`output=${outputDir}`);

const KEYSTORE_ENV_FILE = path.join(process.env['KEYSTORE_DIRECTORY'], 'zowe-certificates.env');
const INSTANCE_PATHS = {
  'ROOT_DIR': "/home/zowe/install",
  'JAVA_HOME': "/usr/local/openjdk-8",
  'NODE_HOME':'/usr/local/node',
  'KEYSTORE_DIRECTORY': "/home/zowe/certs"
}

const KEYSTORE_KEYS = ['KEYSTORE', 'TRUSTSTORE', 'KEYSTORE_KEY', 'KEYSTORE_CERTIFICATE', 'KEYSTORE_CERTIFICATE_AUTHORITY'];

const CONVERT_DIR_EXCEPTIONS = [ 'workspace/api-mediation/api-defs' ];

if (toType == fromType) {
  //this may be used to copy-paste duplicate instances in the future?
  console.error(`Error: same type migration not yet implemented`);
  process.exit(2);
}
if (fromType == TYPE_ZOS && toType == TYPE_CONTAINER) {
  migrateZosContainer();
} else if (fromType == TYPE_ZOS && toType == TYPE_CONTAINER_BUNDLE) {
  migrateZosBundle();
} else if (fromType == TYPE_CONTAINER && toType == TYPE_ZOS) {
  migrateContainerZos();
} else if (fromType == TYPE_CONTAINER_BUNDLE && toType == TYPE_ZOS) {
  migrateBundleZos();
} else if (fromType == TYPE_CONTAINER_BUNDLE && toType == TYPE_CONTAINER) {
  migrateBundleContainer();
} else if (fromType == TYPE_CONTAINER && toType == TYPE_CONTAINER_BUNDLE) {
  migrateContainerBundle();
} else {
  console.error(`Error: unimplemented migration from ${fromType} to ${toType}`);
  process.exit(3);
}
console.warn("Path references for 3rd party components are not altered by this tool. Please review third party component documentation if further correction is needed");

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
    migrateConfigZosBundle();
    //simple conversion: reading files and writing them will do ebcdic-ascii conversion automatically!
    convertRecursively(path.join(instanceDir, 'workspace'), path.join(outputDir, 'instance', 'workspace'), undefined, WORKSPACE_DIR, simpleConvert);
  } else {
    //no tagging info, this is going to be guesswork.
    console.error(`Error: Cannot migrate instance while not on z/OS. Rerun this script on z/OS.`);
    process.exit(4);
  }
}

//ascii -> ebcdic, path updating
//tagfiles except for a few.
function migrateBundleZos() {
  if (isZos) {
    //instance
    fs.copySync(instanceDir, path.join(outputDir, 'instance'));
    tagRecursively(instanceDir, path.join(outputDir, 'instance'), exceptions);
    //updatepaths
    console.log('Run zowe-configure-instance.sh on this to finalize');

    //keystore
    fs.copySync(process.env['KEYSTORE_DIRECTORY'], path.join(outputDir, 'keystore'));
    tagRecursively(process.env['KEYSTORE_DIRECTORY'], path.join(outputDir, 'keystore'), []);
    //updatepaths
  } else {
    //chtag doesnt exist, needs iconv
    console.error(`Error: Cannot migrate instance while not on z/OS. Rerun this script on z/OS.`);
    process.exit(4);
  }
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
  fs.writeFileSync(path.join(outputDir, 'keystore', 'zowe-certificates.env'), fs.readFileSync(KEYSTORE_ENV_FILE,'utf8'));
  convertRecursively(process.env['KEYSTORE_DIRECTORY'], path.join(outputDir, 'keystore'), undefined, WORKSPACE_DIR, certConvert);
  setDockerKeystorePaths();
}

function migrateConfigZosBundle() {
  //migrate instance minus workspace
  convertRecursively(instanceDir, path.join(outputDir, 'instance'), undefined, WORKSPACE_DIR, simpleConvert);
  setDockerInstancePaths();
}

function setDockerKeystorePaths() {
  let keystore = fs.readFileSync(path.join(outputDir, 'keystore', 'zowe-certificates.env'), 'utf8');
  let lines = keystore.split('\n');
  let keystoreDir = process.env['KEYSTORE_DIRECTORY'];
  const migrateDir = path.join(outputDir, 'keystore', 'migrated');

  for (let i = 0; i < lines.length; i++) {
    let line = lines[i].trim();
    for (let j = 0; j < KEYSTORE_KEYS.length; j++) {
      let key = KEYSTORE_KEYS[j];
      if (line.startsWith(key+'=')) {
        let value=line.substring(key.length+1);
        if (value.startsWith(keystoreDir)) {
          lines[i] = key + '=' + value.replace(keystoreDir, INSTANCE_PATHS.KEYSTORE_DIRECTORY);
        } else {
          //object does not originate in keystore. copy it out
          let filename = path.basename(value);
          let buf = fs.readFileSync(value);
          try {
            fs.mkdirSync(migrateDir);
          } catch (e) {
            if (e.code != 'EEXIST') {
              throw e;
            }
          }

          let destinationPath = path.join(migrateDir, filename);
          if (isTextCert(buf)) {
            fs.writeFileSync(destinationPath, fs.readFileSync(value, 'utf8'));
          } else {
            fs.writeFileSync(destinationPath, buf);
          }
          lines[i] = key + '=' + path.join(INSTANCE_PATHS.KEYSTORE_DIRECTORY, 'migrated', filename);
        }
        break;
      }
    };
  }
  keystore = lines.join('\n');
  fs.writeFileSync(path.join(outputDir, 'keystore', 'zowe-certificates.env'), keystore);
}


function setZosInstancePaths(keystoreDir) {
  const nodePath = process.env['_'];
  try { 
    const javaPath = execSync('type java').substring(8); //omit "java is"
  } catch (e) {
    console.error("Java could not be located, migration cannot continue");
    process.exit(5);
  }

}

function setDockerInstancePaths() {
  let instance = fs.readFileSync(path.join(outputDir, 'instance', 'instance.env'), 'utf8');
  let lines = instance.split('\n');
  const keys = Object.keys(INSTANCE_PATHS);
  for (let i = 0; i < lines.length; i++) {
    let line = lines[i].trim();
    for (let j = 0; j < keys.length; j++) {
      let key = keys[j];
      if (line.startsWith(key+'=')) {
        lines[i] = key+'='+INSTANCE_PATHS[key];
      }
    };
  }
  instance = lines.join('\n');
  fs.writeFileSync(path.join(outputDir, 'instance', 'instance.env'), instance);
}

function isTextCert(buff) {
  const char = buff[0];
  //look for -----, 0x60, 0x2d, 0x05
  return buff.length > 5 && (buff[0] == buff[1]) && (buff[0] == buff[2]) && (buff[0] == buff[3]) && (buff[0] == buff[4]) && (char == 0x05 || char == 0x2d);
}


function certConvert(fullPath, destinationPath, convertMap) {
  const buff = fs.readFileSync(fullPath);
  if (fullPath.endsWith('.p12')){ //p12 is binary, dont convert
    //copy
    fs.writeFileSync(destinationPath, buff);
  } else {
    if (isTextCert(buff)) {
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
      console.warn(`file '${fullPath}' not identified as text. first char=${buff[0]}`);
      fs.writeFileSync(destinationPath, buff);
    }

  }
}

function simpleConvert(fullPath, destinationPath, convertMap) {
  if (!convertMap) {
    //TODO make more efficient by streaming buffer
    fs.writeFileSync(destinationPath, fs.readFileSync(fullPath, 'utf8'));
  } else if (convertMap != 'copy') {
    const content = fs.readFileSync(fullPath);
    for (let i = 0; i < content.length; i++) {
      content[i] = convertMap[i];
    }
    fs.writeFileSync(destinationPath, content);
  } else {
    fs.copyFileSync(fullPath, destinationPath);
  }
}

function execAndLogErrors(command) {
  try {
    execSync(command);
  } catch (e) {
    //stderr seen here but could be warnings instead of errors
    console.warn(e.stderr);
  }
}

function untagInternal(inputPath, exceptions) {
  const names = fs.readdirSync(inputPath);

  names.forEach(function(name) {
    const fullPath = path.join(inputPath, name);
    let isException = false;
    for (let i = 0; i < exceptions.length; i++) {
      if (fullPath.endsWith(exceptions[i])) {
        isException = true;
        break;
      }
    }
    const stat = fs.statSync(fullPath);
    if (!isException) {
      if (stat.isDirectory()) {
        tagRecursively(fullPath);
      }
    } else if (stat.isDirectory()) {
      execAndLogErrors(`chtag -r -R ${fullPath}`);
    } else {
      execAndLogErrors(`chtag -r ${fullPath}`);
    }
  });
}

function tagRecursively(inputPath, exceptions) {
  //tag
  const tagScriptDir = path.isAbsolute(TAG_FILES_LOCATION) ?
        TAG_FILES_LOCATION :
        path.join(__dirname, TAG_FILES_LOCATION);
  execAndLogErrors(`${tagScriptDir}/tag-files.sh ${inputPath}`);

  //now, untag exceptions
  untagInternal(inputPath);
}

//if convertMap is null, we use nodejs string conversion trick of zos to input ??? and output ascii
//TODO make async
function convertRecursively(inputPath, outputPath, convertMap, ignorePath, convertFunction) {
  try {
    fs.mkdirSync(outputPath);
  } catch (e) {
    if (e.code != 'EEXIST') {
      throw e;
    }
  }
  let dontConvert = false;
  for (let i = 0; i < CONVERT_DIR_EXCEPTIONS.length; i++) {
    if (inputPath.endsWith(CONVERT_DIR_EXCEPTIONS[i])) {
      dontConvert = true;
    }
  }

  const names = fs.readdirSync(inputPath);
  names.forEach(function(name) {
    const fullPath = path.join(inputPath, name);
    const destinationPath = path.join(outputPath, name);
    if (fullPath != ignorePath) {
      const stat = fs.statSync(fullPath);
      if (stat.isDirectory()) {
        try {
          fs.mkdirSync(destinationPath);
        } catch (e) {
          if (e.code != 'EEXIST') {
            throw e;
          }
        }
        convertRecursively(fullPath, destinationPath, convertMap, ignorePath, convertFunction);
      } else {
        convertFunction(fullPath, destinationPath, dontConvert ? 'copy' : convertMap);
      }
    }
  });
}
