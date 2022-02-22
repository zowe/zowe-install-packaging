/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2021
*/
const path = require('path');
const fs = require('fs');
const { EXPERIMENTAL, HELP, EXAMPLES, EXCLUSIVE_PARAMETERS, PARAMETERS, ERRORS } = require('./dot-file-structure');

const documentationTypes = [EXPERIMENTAL, HELP, EXAMPLES, EXCLUSIVE_PARAMETERS, PARAMETERS, ERRORS];

function getDocumentationTree(commandDirectory) {
    const documentationNode = { children: [], command: commandDirectory.command };
    const objectsInDirectory = fs.readdirSync(commandDirectory.dir);

    for (const file of objectsInDirectory) {
        const objectPath = path.join(commandDirectory.dir, file);

        if (fs.statSync(objectPath).isDirectory()) {
            documentationNode.children.push(getDocumentationTree({ dir: objectPath, command: path.basename(objectPath) }));
        } else {
            const docFileType = documentationTypes.find((df) => df.fileName === file);
            if (docFileType) {
                documentationNode[docFileType.fileName] = objectPath;
            }
        }
    }

    return documentationNode;
}

module.exports = {
    getDocumentationTree
};
