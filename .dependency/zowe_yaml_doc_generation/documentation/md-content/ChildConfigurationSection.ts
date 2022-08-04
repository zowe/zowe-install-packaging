import { SEPARATOR, SUB_SECTION_HEADER } from '../md-constants';
import { hasNestedConfigurationBlock, getRelativePathForChild } from '../util';
import ISection from '../types/ISection';
import IMdDocumentation from '../types/IMdDocumentation';
import { Schema, SchemaNode } from '../types';

export default class ChildConfigurationSection implements ISection {
    private schemaDocumentation: IMdDocumentation;

    constructor(jsonSchemaDocumetation: IMdDocumentation) {
        this.schemaDocumentation = jsonSchemaDocumetation;
    }

    generateMdContent(curSchemaNode: SchemaNode, headingPrefix: string) {
        const { schema: curSchema, metadata } = curSchemaNode;
        const subSectionPrefix = headingPrefix + SUB_SECTION_HEADER;

        const nestedChildBulletPoints = [];
        const embeddedChildBulletPoints = [];
        let aggregatedChildMdContent = '';

        if (hasNestedConfigurationBlock(curSchema)) {
            if (curSchema.properties) {
                for (const [childSchemaKey, childSchema] of Object.entries(curSchema.properties)) {
                    if (hasNestedConfigurationBlock(childSchema)) {
                        nestedChildBulletPoints.push(`* [${childSchemaKey}](./${getRelativePathForChild(childSchema, childSchemaKey, metadata.fileName ?? '', false)})`);
                    } else {
                        const { metadata: childMetadata, mdContent: childMdContent } = this.schemaDocumentation.generateDocumentationForNode(childSchema, childSchemaKey, curSchemaNode, false, headingPrefix + '##');
                        embeddedChildBulletPoints.push(`* ${childMetadata.anchor}`);
                        aggregatedChildMdContent += childMdContent;
                    }
                }
            }
            if (curSchema.patternProperties) {
                for (const [childSchemaKey, childSchema] of Object.entries(curSchema.patternProperties)) {
                    if (hasNestedConfigurationBlock(childSchema)) {
                        nestedChildBulletPoints.push(`* [patternProperty](./${getRelativePathForChild(childSchema, childSchemaKey, metadata.fileName ?? '', true)})`);
                    } else {
                        const { metadata: childMetadata, mdContent: childMdContent } = this.schemaDocumentation.generateDocumentationForNode(childSchema, childSchemaKey, curSchemaNode, false, headingPrefix + '##');
                        embeddedChildBulletPoints.push(`* ${childMetadata.anchor}`);
                        aggregatedChildMdContent += childMdContent;
                    }
                }
            }
        }

        if (!aggregatedChildMdContent && !nestedChildBulletPoints.length && !embeddedChildBulletPoints.length) {
            return ''; // no child configuration
        }

        let mdContent = `${subSectionPrefix}Child properties${SEPARATOR}`;

        if (additionalPropertiesAllowed(curSchema)) {
            mdContent += `Additional properties are allowed.${SEPARATOR}`;
        }

        if (nestedChildBulletPoints.length) {
            mdContent += `#${subSectionPrefix}Nested configuration blocks${SEPARATOR}${nestedChildBulletPoints.join('\n')}${SEPARATOR}`;
        }

        if (embeddedChildBulletPoints.length) {
            mdContent += `#${subSectionPrefix}Configuration properties${SEPARATOR}${embeddedChildBulletPoints.join('\n')}${SEPARATOR}`;
        }

        if (aggregatedChildMdContent) {
            mdContent += aggregatedChildMdContent + SEPARATOR;
        }

        return mdContent;
    }
}

function additionalPropertiesAllowed(curSchema: Schema) {
    // if no child properties then cannot have additional properties, even if additionalProperties is not present
    // need strict equality, not present means additionalProperties=true
    return curSchema.properties && curSchema.additionalProperties !== false;
}
