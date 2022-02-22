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
const MD_TABLE_ROW_DELIMITER = '\n';
const MD_TABLE_ENTRY_DELIMITER = '|';

const TABLE_ENTRY_DELIMITER = '|';
const TABLE_ROW_DELIMITER = '\n';

// order content will appear, with prefix/postfix as needed
const orderedDocumentationTypes = [
    { ...HELP, prefix: SECTION_HEADER_PREFIX + 'Description' + SEPARATOR },
    { ...EXPERIMENTAL, prefix: '**', postfix: '**' },
    { ...EXAMPLES, prefix: SECTION_HEADER_PREFIX + 'Examples' + SEPARATOR },
    { ...EXCLUSIVE_PARAMETERS, prefix: SECTION_HEADER_PREFIX + 'Exclusive parameters' + SEPARATOR },
    { ...PARAMETERS, prefix: SECTION_HEADER_PREFIX + 'Parameters' + SEPARATOR },
    { ...ERRORS, prefix: SECTION_HEADER_PREFIX + 'Errors' + SEPARATOR }
];

function assembleDocumentationElementsForNode(curNode, parentNode) {
    const fileName = getFileName(curNode.command, parentNode.fileName);
    const command = parentNode.command ? parentNode.command + ' ' + curNode.command : curNode.command;
    const link = `[${curNode.command}](./${fileName})`;
    const title = parentNode.title ? `${parentNode.title} > ${link}` : '# ' + link;

    const docElements = {
        fileName,
        command,
        title,
        children: curNode.children,
    };

    for (const docType of orderedDocumentationTypes) {
        const docForType = { content: '', parentContent: '' };

        if (hasDocType(curNode, docType)) {
            if (docType.meaning) {
                docForType.content = docType.meaning;
            } else {
                const docFileContent = fs.readFileSync(curNode[docType.fileName], 'utf-8');
                if (docType.table) {
                    docForType.content = docFileContent.split(/$/gm).map(line =>  // filter out ignored table entries
                        line
                            .trim()
                            .split(docType.table.delimiter)
                            .filter((_, index) => !docType.table.orderedSegments[index] || !docType.table.orderedSegments[index].ignore)
                            .join(TABLE_ENTRY_DELIMITER)
                    )
                    .join(TABLE_ROW_DELIMITER);
                } else {
                    docForType.content = docFileContent;
                }
            }
        }

        if (hasDocType(parentNode, docType) && docType.inherit) {
            let parentContent = '';
            if (parentNode[docType.fileName].content) {
                parentContent += parentNode[docType.fileName].content;
            }
            if (parentNode[docType.fileName].parentContent) {
                parentContent += parentNode[docType.fileName].parentContent;
            }
            docForType.parentContent = parentContent;
        }

        docElements[docType.fileName] = docForType;
    }

    return docElements
}

function generateDocumentationForNode(curNode, parentNode) {
    const assembledDocNode = assembleDocumentationElementsForNode(curNode, parentNode);
    const { title, command, children, fileName } = assembledDocNode;

    let mdContent = title + SEPARATOR + `\t${command}`;

    if (children.length) {
        mdContent += ' [sub-command [sub-command]...] [parameter [parameter]...]' + SEPARATOR;
        mdContent += SECTION_HEADER_PREFIX + 'Sub-commands' + SEPARATOR + children.map(c => `* [${c.command}](./${getFileName(c.command, fileName)})`).join('\n');
    } else {
        mdContent += ' [parameter [parameter]...]';
    }

    for (const docType of orderedDocumentationTypes) {
        let docContent = '';
        if (hasDocType(assembledDocNode, docType) && (assembledDocNode[docType.fileName].content || assembledDocNode[docType.fileName].parentContent)) {
            const rawContent = assembledDocNode[docType.fileName].content + assembledDocNode[docType.fileName].parentContent;

            if (docType.table) {
                const filteredSegments = docType.table.orderedSegments.filter(o => !o.ignore);
                docContent += filteredSegments.map(o => o.meaning).join(MD_TABLE_ENTRY_DELIMITER) + MD_TABLE_ROW_DELIMITER; // Set table headings
                docContent += filteredSegments.map(_ => '|---').join('') + MD_TABLE_ROW_DELIMITER; // Set table separator between headings and fields

                docContent += rawContent.split(TABLE_ROW_DELIMITER).map(line => line.trim().split(TABLE_ENTRY_DELIMITER) // transform table entries
                    .map((segment, index) => {
                        if (docType.table.orderedSegments[index] && docType.table.orderedSegments[index].transform) {
                            return docType.table.orderedSegments[index].transform(segment);
                        }
                        return segment;
                    })
                    .join(MD_TABLE_ENTRY_DELIMITER)) // join fields in a row
                    .join(MD_TABLE_ROW_DELIMITER); // join rows with newline
            } else {
                docContent += rawContent;
            }
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
        parts: assembledDocNode,
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
