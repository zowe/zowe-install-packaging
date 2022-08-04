import fs from 'fs';
import path from 'path';

import { ChildConfigurationSection, ConstraintsSection, DescriptionSection, TitleSection } from './md-content';
import { ROOT_NAME, FILE_EXT } from './md-constants';
import { getSchemaFileName, hasNestedConfigurationBlock } from './util';
import { IMdDocumentation, ISection, Schema, SchemaNode, SchemaNodeMetadata } from './types';

const GENERATED_DOCS_DIR = path.join(__dirname, './generated');

export default class JsonSchemaDocumentation implements IMdDocumentation {
    private sections: ISection[];

    constructor() {
        const titleSection = new TitleSection();
        const descriptionSection = new DescriptionSection();
        const constraintsSection = new ConstraintsSection(this);
        const childConfigurationSection = new ChildConfigurationSection(this);

        this.sections = [
            // defines what sections appear in generated md files, and in the order of this array
            titleSection,
            descriptionSection,
            constraintsSection,
            childConfigurationSection
        ]
    }

    writeMdFiles(schema: Schema, schemaKey: string, parentNode = { schema: {}, metadata: {} }, isPatternProp = false) {
        const { metadata, mdContent } = this.generateDocumentationForNode(schema, schemaKey, parentNode, isPatternProp);
        const dirToWriteFile = `${GENERATED_DOCS_DIR}/${metadata.directory}`;
        if (!fs.existsSync(dirToWriteFile)) {
            fs.mkdirSync(dirToWriteFile, { recursive: true });
        }
        fs.writeFileSync(`${dirToWriteFile}/${metadata.fileName}${FILE_EXT}`, mdContent);

        if (schema.properties) {
            for (const [childSchemaKey, childSchema] of Object.entries(schema.properties)) {
                if (hasNestedConfigurationBlock(childSchema)) {
                    this.writeMdFiles(childSchema, childSchemaKey, { schema, metadata }, false);
                }
            }
        }

        if (schema.patternProperties) {
            for (const [childSchemaKey, childSchema] of Object.entries(schema.patternProperties)) {
                if (hasNestedConfigurationBlock(childSchema)) {
                    this.writeMdFiles(childSchema, childSchemaKey, { schema, metadata }, true);
                }
            }
        }
    }

    generateDocumentationForNode(curSchema: Schema, curSchemaKey: string, parentNode: SchemaNode, isPatternProp: boolean, headingPrefix = '') {
        const metadata = assembleSchemaMetadata(curSchema, curSchemaKey, parentNode.metadata, isPatternProp);
        const curSchemaNode = { schema: curSchema, metadata };

        let mdContent = '';
        for (const section of this.sections) {
            mdContent += section.generateMdContent(curSchemaNode, headingPrefix);
        }

        const cleanedMdContent = mdContent.replace('<', '{'); // TODO shouldn't go here, should go in automation that moves over to docs site repo
        return {
            metadata,
            mdContent: cleanedMdContent
        };
    }
}

function assembleSchemaMetadata(curSchema: Schema, curSchemaKey: string, parentSchemaMetadata: SchemaNodeMetadata, isPatternProperty: boolean): SchemaNodeMetadata {
    const fileName = getSchemaFileName(curSchemaKey, parentSchemaMetadata.fileName ?? '', isPatternProperty);
    const title = isPatternProperty ? 'patternProperty' : curSchemaKey;
    const yamlKey = parentSchemaMetadata.yamlKey && parentSchemaMetadata.yamlKey !== ROOT_NAME ? `${parentSchemaMetadata.yamlKey}.${title}` : title;
    const link = `[${title}](./${fileName}${FILE_EXT})`;
    const anchor = `[${title}](#${title.toLowerCase()})`; // md anchor is lower case
    const linkKeyElements = parentSchemaMetadata.linkKeyElements ? [...parentSchemaMetadata.linkKeyElements, link] : [link];

    let relPathToParentLinks = './';
    let directory = parentSchemaMetadata.directory ? parentSchemaMetadata.directory : '.';
    if (curSchema.properties) {
        directory += `/${fileName}`;
        relPathToParentLinks = '../';
    }

    // add '../'to make link to parent keys proper given the directory structure
    for (let elementIndex = 0; elementIndex < linkKeyElements.length - 1; elementIndex++) {
        linkKeyElements[elementIndex] = linkKeyElements[elementIndex].replace(/\(/, '(' + relPathToParentLinks); // path starts after '(', so add '../' after '('
    }

    const linkYamlKey = linkKeyElements.join(' > ');

    // don't use anchor from parents as they may be in a different file, can just link to the file
    const anchorKeyElements = parentSchemaMetadata.linkKeyElements && parentSchemaMetadata.fileName !== ROOT_NAME ? [...parentSchemaMetadata.linkKeyElements, anchor] : [anchor];
    const anchorKey = anchorKeyElements.join(' > ');

    return {
        title,
        fileName,
        linkKeyElements,
        directory,
        yamlKey,
        anchor,
        anchorKey,
        linkYamlKey,
        curSchemaKey,
        isPatternProperty
    }
}

// TODO dry with zwe doc gen?
