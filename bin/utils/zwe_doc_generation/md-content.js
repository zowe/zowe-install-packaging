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
const { EXPERIMENTAL, HELP, EXAMPLES, EXCLUSIVE_PARAMETERS, PARAMETERS, ERRORS } = require('./dot-file-structure');

const SEPARATOR = '\n\n';
const SECTION_HEADER_PREFIX = '## ';

// order content will appear, with heading prefix if applicable
const orderedDocumentationTypes = [
    { ...HELP, prefix: SECTION_HEADER_PREFIX + 'Description' + SEPARATOR },
    { ...EXPERIMENTAL, prefix: '**', postfix: '**' },
    { ...EXAMPLES, prefix: SECTION_HEADER_PREFIX + 'Examples' + SEPARATOR },
    { ...EXCLUSIVE_PARAMETERS, prefix: SECTION_HEADER_PREFIX + 'Exclusive parameters' + SEPARATOR },
    { ...PARAMETERS, prefix: SECTION_HEADER_PREFIX + 'Parameters' + SEPARATOR },
    { ...ERRORS, prefix: SECTION_HEADER_PREFIX + 'Errors' + SEPARATOR }
];

function generateDocumentationForNode(curNode, parentNode) {
    const fileName = getFileName(curNode.command, parentNode.fileName);
    const command = parentNode.command ? parentNode.command + ' ' + curNode.command : curNode.command;
    const link = `[${curNode.command}](./${fileName})`;
    const title = parentNode.title ? `${parentNode.title} > ${link}` : '# ' + link;

    let mdContent = title + SEPARATOR + `\t${command}`;

    if (curNode.children && curNode.children.length) {
        mdContent += ' [sub-command [sub-command]...] [parameter [parameter]...]' + SEPARATOR;
        mdContent += SECTION_HEADER_PREFIX + 'Sub-commands' + SEPARATOR + curNode.children.map(c => `* [${c.command}](./${getFileName(c.command, fileName)})`).join('\n');
    } else {
        mdContent += ' [parameter [parameter]...]';
    }

    for (const docType of orderedDocumentationTypes) {
        let docContent = '';
        if (hasDocType(curNode, docType)) {
            if (docType.meaning) {
                docContent += docType.meaning;
            } else {
                const docFileContent = fs.readFileSync(curNode[docType.fileName], 'utf-8');
                if (docType.syntax) {
                    const filteredSegments = docType.syntax.orderedSegments.filter(o => !o.ignore);
                    docContent += filteredSegments.map(o => o.meaning).join('|') + '\n'; // Set table headings
                    docContent += filteredSegments.map(_ => '|---').join('') + '\n'; // Set table separator between headings and fields

                    docContent += docFileContent.split(/$/gm).map(line => line.trim().split(docType.syntax.delimiter) // transform table entries
                        .filter((_, index) => !docType.syntax.orderedSegments[index] || !docType.syntax.orderedSegments[index].ignore)
                        .map((segment, index) => {
                            if (docType.syntax.orderedSegments[index] && docType.syntax.orderedSegments[index].transform) {
                                return docType.syntax.orderedSegments[index].transform(segment);
                            }
                            return segment;
                        })
                        .join('|')) // join fields in a row
                        .join('\n'); // join rows with newline
                } else {
                    docContent += docFileContent;
                }
            }
            // TODO inherited content - may need to return object of each type of doc, with another function for assembling them in the right order
        }

        if (docContent) {
            mdContent += SEPARATOR;
            if (docType.prefix) {
                mdContent += docType.prefix;
            }
            mdContent += docContent;
            if (docType.postfix) {
                mdContent += docType.postfix;
            }
        }
    }

    return {
        fileName: fileName,
        command: command,
        title: title,
        link: link,
        mdContent: mdContent
    };
}

function getFileName(command, parentFileName) {
    return parentFileName ? `${parentFileName}-${command}` : command;
}

function hasDocType(docNode, type) {
    return docNode[type.fileName] !== null & docNode[type.fileName] !== undefined;
}

module.exports = {
    generateDocumentationForNode
};
