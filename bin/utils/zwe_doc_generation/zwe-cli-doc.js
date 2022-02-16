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

const {FILE_CONTENT_TOKEN, SEPARATOR, orderedDocumentationTypes} = require('./doc-configuration');

const docsRootDirectory = path.join(__dirname, '../../commands');
const generatedDocDirectory = path.join(__dirname, './generated');

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
            const docFileType = orderedDocumentationTypes.find((df) => df.fileName === file);
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

function writeMdFiles(docNode, parent = {}) {
    const command = parent.command ? `${parent.command} ${docNode.command}` : docNode.command;
    if (docNode.children && docNode.children.length) {
        for (const child of docNode.children) {
            writeMdFiles(child, { command });
        }
    }

    const mdContent = getMdContentForNode(docNode, parent);
    fs.writeFileSync(`${generatedDocDirectory}/doc-${command.replace(/\s/g, '-')}.md`, mdContent);
}

function getMdContentForNode(docNode, parent) {
    // TODO need to apply parent experimental, parameters and errors to child docs
    // TODO need to link to children and parent commands
    let mdContent = `# ${parent.command} ${docNode.command}`;

    for (const type of orderedDocumentationTypes) {
        if (docNode[type.key]) {
            let typeContent = type.content;
            if (typeContent.includes(FILE_CONTENT_TOKEN)) {
                let fileContent = fs.readFileSync(docNode[type.key], 'utf-8');
                if (type.fileContentTransformation) {
                    fileContent = type.fileContentTransformation(fileContent);
                }

                typeContent = typeContent.replace(FILE_CONTENT_TOKEN, fileContent);
            }
            mdContent = mdContent + SEPARATOR + typeContent;
        }
    }

    return mdContent;
}