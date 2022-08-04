import { SchemaNode } from "./SchemaNode";

export default interface Section {
    generateMdContent: (curSchemaNode: SchemaNode, headingPrefix: string) => string;
};
