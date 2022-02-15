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

const SEPARATOR = '\n\n';
const FILE_CONTENT_TOKEN = '%f';
const SECTION_HEADER = '## ';

const EXPERIMENTAL = {
    fileName: '.experimental',
    key: 'experimental',
    order: 1,
    content: '**Warning:** This command is for experimental purposes and may not fully function.'
};
const HELP = {
    fileName: '.help',
    key: 'help',
    order: 2,
    content: FILE_CONTENT_TOKEN
};
const EXAMPLES = {
    fileName: '.examples',
    key: 'examples',
    order: 3,
    content: `${SECTION_HEADER}Examples${SEPARATOR}${FILE_CONTENT_TOKEN}`
};
const EXCLUSIVE_PARAMETERS = {
    fileName: '.exclusive-parameters',
    key: 'exclusive-parameters',
    order: 4,
    content: `${SECTION_HEADER}Parameters${SEPARATOR}${FILE_CONTENT_TOKEN}`
};
const PARAMETERS = {
    fileName: '.parameters',
    key: 'parameters',
    order: 5,
    content: `${SECTION_HEADER}Parent command parameters${SEPARATOR}${FILE_CONTENT_TOKEN}`
};
const ERRORS = {
    fileName: '.errors',
    key: 'errors',
    order: 6,
    content: `${SECTION_HEADER}Errors${SEPARATOR}${FILE_CONTENT_TOKEN}`
};

const documentationTypes = [
    EXPERIMENTAL, HELP, EXAMPLES, EXCLUSIVE_PARAMETERS, PARAMETERS, ERRORS
];

const docsTree = getDocumentationTree(docsRootDirectory);
console.log(JSON.stringify(docsTree, null, 2));

writeMdFiles(docsTree); // TODO can this process be merged into getting the docs tree? So its one pass, not two?

function getDocumentationTree(directory) {
    const documentationNode = { children: [] };
    const objectsInDirectory = fs.readdirSync(directory);

    for (const file of objectsInDirectory) {
        const objectPath = path.join(directory, file);
        if (fs.statSync(objectPath).isDirectory()) {
            documentationNode.children.push(getDocumentationTree(objectPath));
        } else {
            const docFileType = documentationTypes.find((df) => df.fileName === file);
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
    // TODO need to transform from . file format to md format (e.g. tables)
    // TODO need to apply parent experimental, parameters and errors to child docs
    let mdContent = `# ${command}`;

    const orderedDocumentationTypes = documentationTypes.sort((a, b) => a.order - b.order); // ensure append in correct order
    for (const type of orderedDocumentationTypes) {
        if (docNode[type.key]) {
            let typeContent = type.content;
            if (typeContent.includes(FILE_CONTENT_TOKEN)){ 
                const fileContent = fs.readFileSync(docNode[type.key], 'utf-8');
                typeContent = typeContent.replace(FILE_CONTENT_TOKEN, fileContent);
            }
            mdContent = mdContent + SEPARATOR + typeContent;
        }
    }

    return mdContent;
}