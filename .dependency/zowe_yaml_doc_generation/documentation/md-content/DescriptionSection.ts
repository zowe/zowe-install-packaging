import { SEPARATOR, SUB_SECTION_HEADER } from '../md-constants';
import { SchemaNode } from '../types';
import ISection from '../types/ISection';

export default class DescriptionSection implements ISection {
    generateMdContent(curSchemaNode: SchemaNode, headingPrefix: string) {
        const subSectionPrefix = headingPrefix + SUB_SECTION_HEADER;
        const { schema, metadata } = curSchemaNode;

        let mdContent = `${subSectionPrefix}Description${SEPARATOR}`;

        if (metadata.isPatternProperty) {
            mdContent += `Properties matching regex: ${SEPARATOR}`; // TODO add actual regex
        }

        mdContent += `\t${metadata.yamlKey}${SEPARATOR}${schema.description || ''}${SEPARATOR}`;

        if (schema.default !== null && schema.default !== undefined) {
            mdContent += `**Default value:** \`${schema.default}\`${SEPARATOR}`;
        }

        if (schema.examples) {
            mdContent += `#${subSectionPrefix}Example values${SEPARATOR}* \`${schema.examples.join('`\n* `')}\`${SEPARATOR}`;
        }

        return mdContent;
    }
}
