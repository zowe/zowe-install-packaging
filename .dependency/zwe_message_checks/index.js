/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2021
 */
const fs = require('fs-extra');
const path = require('path');
const sc = require('string-comparison');
const _ = require('lodash');
const { getDocumentationTree } = require('../zwe_doc_generation/doc-tree');

const zweRootDir = path.resolve(__dirname, '..','..', 'bin');
const rootDocNode = getDocumentationTree({ dir: path.join(zweRootDir, 'commands'), command: 'zwe' });

let statusFailed = false;
const discoveredMsgs = []; // filled out by getMessagesUsedByImplementations()

// inspect sources in two dirs: commands and libs. we miss zwe itself and code exceptions for it
const dirs = [path.join(zweRootDir, 'commands'), path.join(zweRootDir, 'libs')];
for (const dir of dirs) {
  discoveredMsgs.push(...getMessagesUsedByImplementations(dir));
} 

// second, collect all message ids listed in .errors
const collectedMsgs = collectMessageIds(rootDocNode);
const dupErrors = findDuplicates(collectedMsgs);
console.log('---- Duplicate Message Content or IDs defined in .errors ----\n');
if (dupErrors.length > 0) {
  statusFailed = true;
  for (const error of dupErrors) {
    console.log(error.message);
  }
}
console.log('')

const flatExpectedMessages = collectedMsgs.map((msg) => msg.id);
const msgTally = {};
for (const msg of flatExpectedMessages) {
  msgTally[msg] = {count: 0};
}

console.log('---- Messages Used and Not Defined in .errors ----');
for(const msgSpec of discoveredMsgs) {
  for(const msg of msgSpec.messages) {
    if (!flatExpectedMessages.includes(msg.messageId)) {
      console.log(`|${msg.messageId}:${msg.message}[${msgSpec.src}]|\n`);
      statusFailed = true;
      continue;
    }
   msgTally[msg.messageId].count++
  }
}
console.log('')
console.log('---- Unused Messages defined in .errors ----');
for(const msgId of Object.keys(msgTally)) {
  if (msgTally[msgId].count === 0 && msgId !== 'ZWEL0103E') { // ZWEL0103E is in 'zwe', which isn't scanned
    const definition = collectedMsgs.find((it) => it.id === msgId);
    console.log(`Unused message: ${msgId} [${definition.source}]`);
    statusFailed = true;
  }
}
console.log()
// this will not set 'statusFailed' since the results may not be accurate.
// toggling the similarity threshold greatly impacts output... setting the threshold lower (closer to 0) suppresses
//   output volume, while setting it higher (closer to 1) will display more messages in the log
console.log('---- Experimental: Messages whose content differs from the definition in .errors ----');
const similarityExceptions = ['The password for data set storing importing certificate (zowe.setup.certificate.keyring.import.password) is not defined in Zowe YAML configuration file.']
for(const msgSpec of discoveredMsgs) {
  for(const msg of msgSpec.messages) {
    const errorDef = collectedMsgs.find((item) => item.id === msg.messageId);
    // lets only examine message contents where we have more than a few characters cut off by a newline
    if (errorDef?.message && msg.message.length > 15 && !similarityExceptions.includes(msg.message)) {
      const similarity = sc.default.levenshtein.similarity(msg.message, errorDef.message);
      if (similarity < 0.35) {
        console.log(`${msg.messageId}:${msg.message}[${msgSpec.src}] VERSUS ${errorDef.id}:${errorDef.message}[${errorDef.source}]\n`);     
      } 
    }

  }
}
console.log()

if (statusFailed) {
  process.exit(1);
}

function findDuplicates(collectedMsgs) {
  const errors = [];
  // flatten and get unique IDs
  const uniqIds = _.uniq(collectedMsgs.map((it) => it.id));
  for (const id of uniqIds) {
    const matchingIds = _.uniqBy(collectedMsgs.filter((it) => it.id === id), 'message')
    //exclude the direct match
    if (matchingIds.length > 1) {
      const errorText = matchingIds.reduce((prev, curr) => prev + `|${curr.message}[${curr.source}]|\n`, '');
      errors.push({type: 'ID', message: `Dup ID: ${id}, ${matchingIds.length} Locations: \n${errorText}`});
    }
  }
  const uniqMsgs = _.uniq(collectedMsgs.map((it) => it.message));
  for (const msg of uniqMsgs) {
    const matchingMsgs =  _.uniqBy(collectedMsgs.filter((it) => it.message === msg), 'id')
    if (matchingMsgs.length > 1) {
      const errorText = matchingMsgs.reduce((prev, curr) => prev + `|${curr.id}[${curr.source}]|\n`, '');
      errors.push({type: 'MSG', message: `Dup MSG: ${msg}, ${matchingMsgs.length} Locations: \n${errorText}`});
    }
  }
  return errors;
}  

function collectMessageIds(docNode) {

  const messages = [];
  if (docNode?.children?.length > 0) {
    for (const child of docNode.children) {
        const recursedResult = collectMessageIds(child);
        messages.push(...recursedResult);
    }
  }
  const errorsFile = docNode?.['.errors']
  if (errorsFile) {
    const lines = fs.readFileSync(errorsFile, 'utf8').split('\n')
    for (const line of lines) {
      const shortErrorsPath = 'bin'+path.sep+errorsFile.split('bin'+path.sep)[1];
      const pieces = line.trim().split('|');
      if (pieces.length > 0 && pieces[0].trim().length > 0) {
        // check for duplicates
        // reconstruct full message string, in case it contained | characters
        const originalMsg = pieces.slice(2).join('|');
        messages.push({ id: pieces[0], message: originalMsg, source: shortErrorsPath });
      }
    }
  }
  return messages;

}

function getMessagesUsedByImplementations(zweDir) {

    const messages = [];

    if (!fs.existsSync(zweDir) && !fs.lstatSync(zweDir).isDirectory()) {
      throw new Error('Bad directory passed to zwe message checks: '+zweDir);
    }
  
    const files = fs.readdirSync(zweDir);
    const dirs = files.filter((file) => fs.statSync(path.join(zweDir, file)).isDirectory());
    const srcFiles = files.filter((file) => file.endsWith('.ts') || file.endsWith('.sh') || file.endsWith('zwe'));
    dirs.forEach((dir) => 
      messages.push(...getMessagesUsedByImplementations(path.join(zweDir, dir))));
    for(const src of srcFiles) {
      // find messages matching ZWELXXX
      const srcFile = path.join(zweDir, src);
      const srcFileShort = 'bin'+path.sep+srcFile.split('bin'+path.sep)[1];
      const content = fs.readFileSync(srcFile, 'utf8');
      const matches = content.matchAll(/(ZWEL\d{4}[EIDTW])(.*?)["'`]/gm);
  
      for (const match of matches) {
        const message = match[2].replaceAll(/\${.*?}/gm,'%s');
        if (!messages.includes(message)) {
          const leafDir = path.basename(path.dirname(srcFile));
          const existing = messages.find((item) => item.src === srcFileShort);
          if (existing) {
           existing.messages.push({messageId: match[1], message: message.substring(1).trim()});
          } else {
            messages.push({ command: leafDir, src: srcFileShort, messages: [{messageId: match[1], message: message.substring(1).trim() }]});
          }
        }
      }
    }
    return messages;
}

