import { SEPARATOR } from '../md-constants';
import { SchemaNode } from '../types';
import ISection from '../types/ISection';

export default class TitleSection implements ISection {
    generateMdContent(curSchemaNode: SchemaNode, headingPrefix: string) {
        const { metadata } = curSchemaNode;

        const isEmbeddedChild = headingPrefix !== '';

        let mdContent = `${headingPrefix}# ${metadata.title}${SEPARATOR}`;

        if (isEmbeddedChild) {
            mdContent += `${metadata.anchorKey}${SEPARATOR}`;
        } else {
            mdContent += `${metadata.linkYamlKey}${SEPARATOR}`;
        }

        return mdContent;
    }
}
