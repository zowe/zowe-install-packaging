/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2021
 */

const fs = require('fs');
const path = require('path');

const docsRootDirectory = path.join(__dirname, '../../commands');
const generatedDocDirectory = path.join(__dirname, './generated');

const HELP = {
    fileName: '.help',
    key: 'help',
    order: 1,
    title: 'Help'
};
const EXAMPLES = {
    fileName: '.examples',
    key: 'examples',
    order: 2,
    title: 'Examples'
};
const PARAMETERS = {
    fileName: '.parameters',
    key: 'parameters',
    order: 3,
    title: 'Parameters'
};
const EXCLUSIVE_PARAMETERS = {
    fileName: '.exclusive-parameters',
    key: 'exclusive-parameters'
};
const ERRORS = {
    fileName: '.errors',
    key: 'errors',
    order: 4,
    title: 'Errors'
};
const EXPERIMENTAL = {
    fileName: '.experimental',
    key: 'experimental'
};

const documentationFiles = [
    HELP, EXAMPLES, PARAMETERS, EXCLUSIVE_PARAMETERS, ERRORS, EXPERIMENTAL
]

const docsTree = getDocumentationTree(docsRootDirectory);
console.log(JSON.stringify(docsTree, null, 2));

writeMdFiles(docsTree);

function getDocumentationTree(directory) {
    const documentationNode = { children: [] };
    const objectsInDirectory = fs.readdirSync(directory);

    for (const file of objectsInDirectory) {
        const objectPath = path.join(directory, file);
        if (fs.statSync(objectPath).isDirectory()) {
            documentationNode.children.push(getDocumentationTree(objectPath));
        } else {
            const docFileType = documentationFiles.find((df) => df.fileName === file);
            if (docFileType) {
                documentationNode.command = path.basename(directory);
                if (documentationNode.command === 'commands') {
                    documentationNode.command = 'zwe'; // special case for root directory name
                }
                documentationNode[docFileType.key] = objectPath;
            }
        }
    }

    return documentationNode;
}

function writeMdFiles(docsNode, parent) {
    const command = parent ? `${parent} ${docsNode.command}` : docsNode.command;
    if (docsNode.children && docsNode.children.length) {
        for (const child of docsNode.children) {
            writeMdFiles(child, command);
        }
    }

    const mdContent = getMdContentForNode(docsNode, command);
    fs.writeFileSync(`${generatedDocDirectory}/doc-${command.replace(/\s/g, '-')}.md`, mdContent);
}

function getMdContentForNode(docNode, command) {
    // TODO need to order the file content
    // TODO need to transform from . file format to md format (e.g. tables)
    // TODO need to apply parent experimental, parameters and errors to child docs
    let mdContent = `# ${command}`;

    if (docNode[EXPERIMENTAL.key]) {
        mdContent = mdContent + '\n\n**Warning:** This command is for experimental purposes and may not fully function.';
    }

    for (const fileType of documentationFiles) {
        if (docNode[fileType.key]) {
            const fileContent = fs.readFileSync(docNode[fileType.key], 'utf-8');
            mdContent = mdContent + `\n\n## ${fileType.key}\n\n${fileContent}`;
        }
    }

    return mdContent;
}