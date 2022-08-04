const { SEPARATOR } = require('./md-constants');
const { getRelativePathForChild } = require('./util');

class ConstraintsSection {
    valueConstraints = [
        {
            key: 'required',
            mdGenerator: (value) => `* Must have child property \`${value.join('` defined\n* Must have child property `')}\` defined\n`
        },
        {
            // TODO support object types
            key: 'type',
            mdGenerator: (value) => `* Property value must be a ${value}`
        },
        // constants
        {
            key: 'const',
            mdGenerator: (value) => `* Property value must be ${value}`
        },
        {
            key: 'enum',
            // value is an array
            mdGenerator: (value) => `* Property value must be one of \`${value.join('`,`')}\``
        },
        // string constraints
        {
            key: 'minLength',
            mdGenerator: (value) => `* Property value must be at least ${value} characters`
        },
        {
            key: 'maxLength',
            mdGenerator: (value) => `* Property value must be less than ${value} characters`
        },
        {
            key: 'pattern',
            mdGenerator: (value) => `* Property value must match the regular expression '${value}'`
        },
        // integer constraints
        {
            key: 'multipleOf',
            mdGenerator: (value) => `* Property value must be a multiple of ${value}`
        },
        {
            key: 'minimum',
            mdGenerator: (value) => `* Property value must be at least ${value}`
        },
        {
            key: 'exclusiveMinimum',
            mdGenerator: (value) => `* Property value must be at least ${value + 1}`
        },
        {
            key: 'maximum',
            mdGenerator: (value) => `* Property value must be at most ${value}`
        },
        {
            key: 'exclusiveMaximum',
            mdGenerator: (value) => `* Property value must be ${value - 1}`
        },
        // object constraints
        {
            key: 'minProperties',
            mdGenerator: (value) => `* Property object must have at least ${value} properties`
        },
        {
            key: 'maxProperties',
            mdGenerator: (value) => `* Property object must have at most ${value} properties`
        },
        // content type constraints
        {
            key: 'contentMediaType',
            mdGenerator: (value) => `* Property value must be of media type ${value}`
        },
        {
            key: 'contentEncoding',
            mdGenerator: (value) => `* Property value must be ${value} encoded`
        },
        // TODO array constraints http://json-schema.org/understanding-json-schema/reference/array.html
        // logic constraints
        {
            key: 'oneOf',
            mdGenerator: (oneOfList, extraArgs) => { // TODO args are out of place
                const { curSchemaNode } = extraArgs;
                const { curSchemaKey, fileName: currentFileName } = curSchemaNode.metadata;
                const oneOfBulletPointsList = [];

                for (let i = 0; i < oneOfList.length; i++) {
                    const childSchema = oneOfList[i];
                    const childSchemaKey = oneOfList.title ?? `${curSchemaKey}-oneOf-${i}`; // TODO fix title
                    this.schemaDocumentation.writeMdFiles(childSchema, childSchemaKey, curSchemaNode, false);
                    oneOfBulletPointsList.push(`* [${childSchemaKey}](./${getRelativePathForChild(childSchema, childSchemaKey, currentFileName, false)})`);
                }

                return oneOfBulletPointsList.length ? `* One of the following specifications must be satisfied:\n\t${oneOfBulletPointsList.join('\n\t')}\n` : '';
            }
        },
        {
            key: 'allOf',
            mdGenerator: (allofList, extraArgs) => { // TODO args are out of place
                const { curSchemaNode } = extraArgs;
                const { curSchemaKey, fileName: currentFileName } = curSchemaNode.metadata;
                const allOfBulletPointsList = [];

                for (let i = 0; i < allofList.length; i++) {
                    const childSchema = allofList[i];
                    const childSchemaKey = allofList.title ?? `${curSchemaKey}-allOf-${i}`;
                    this.schemaDocumentation.writeMdFiles(childSchema, childSchemaKey, curSchemaNode, false);
                    allOfBulletPointsList.push(`* [${childSchemaKey}](./${getRelativePathForChild(childSchema, childSchemaKey, currentFileName, false)})`);
                }

                return allOfBulletPointsList.length ? `* One of the following specifications must be satisfied:\n\t${allOfBulletPointsList.join('\n\t')}\n` : '';
            }
        },
        {
            key: 'if',
            // no else or then keys because those schemas will be passed into mdGenerator, and on their own with no if schema they can be ignored
            mdGenerator: (ifSchema, extraArgs) => {
                const { thenSchema, elseSchema, curSchemaNode } = extraArgs;
                const { curSchemaKey, fileName: currentFileName } = curSchemaNode.metadata;

                if (!thenSchema && !elseSchema) {
                    return ''; // no constraints if only an if schema
                }

                const ifLogicBulletPoints = [];
                const ifSchemaKey = ifSchema.title ?? `${curSchemaKey}-if`;
                this.schemaDocumentation.writeMdFiles(ifSchema, ifSchemaKey, curSchemaNode, false);

                const ifSchemaRelativeFilePath = './' + getRelativePathForChild(ifSchema, ifSchemaKey, currentFileName, false);

                if (thenSchema) {
                    const thenSchemaKey = thenSchema.title ?? `${curSchemaKey}-then`;
                    this.schemaDocumentation.writeMdFiles(thenSchema, thenSchemaKey, curSchemaNode, false);

                    const thenSchemaRelativeFilePath = './' + getRelativePathForChild(thenSchema, thenSchemaKey, currentFileName, false);
                    ifLogicBulletPoints.push(`* If the [${ifSchemaKey}](${ifSchemaRelativeFilePath}) schema is satisfied,` +
                        ` then the [${thenSchemaKey}](${thenSchemaRelativeFilePath}) must also be satisfied`);
                }

                if (elseSchema) {
                    const elseSchemaKey = elseSchema.title ?? `${curSchemaKey}-else`;
                    this.schemaDocumentation.writeMdFiles(elseSchema, elseSchemaKey, curSchemaNode, false);

                    const elseSchemaRelativeFilePath = './' + getRelativePathForChild(elseSchema, elseSchemaKey, currentFileName, false);
                    ifLogicBulletPoints.push(`* If the [${ifSchemaKey}](${ifSchemaRelativeFilePath}) schema is **NOT** satisfied,` +
                        ` then the [${elseSchemaKey}](${elseSchemaRelativeFilePath}) must be satisfied`);
                }

                return ifLogicBulletPoints.length ? `* The following if-then-else schema logic must be satisfied:\n\t${ifLogicBulletPoints.join('\n\t')}` : '';
            }
        }
        // TODO should all schema keywords be in here, with priority to determine order of appearance in md file? including e.g. additionalProperties?
    ];

    constructor(jsonSchemaDocumentation) {
        this.schemaDocumentation = jsonSchemaDocumentation;
    }

    generateMdContent(curSchemaNode, subSectionPrefix) {
        const curSchema = curSchemaNode.schema;
        const constraints = [];

        for (const [propKey, constraint] of Object.entries(curSchema)) {
            for (const { key, mdGenerator } of this.valueConstraints) {
                if (key === propKey) {
                    constraints.push(mdGenerator(constraint,
                        // TODO this extra args object is bad
                        {
                            thenSchema: curSchema.then,
                            elseSchema: curSchema.else,
                            curSchemaNode
                        }
                    ));
                }
            }
        }
        return constraints.length ? `${subSectionPrefix}Value constraints${SEPARATOR}${constraints.join('\n')}${SEPARATOR}` : '';
    }
}

module.exports = ConstraintsSection;
