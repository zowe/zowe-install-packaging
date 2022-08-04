import { Schema } from "../../types/Schema";
import { SchemaNode } from "./SchemaNode";

export default interface IMdDocumentation {
    writeMdFiles: (schema: Schema, schemaKey: string, parentNode: SchemaNode, isPatternProp: boolean) => void;
    generateDocumentationForNode: (curSchema: Schema, curSchemaKey: string, parentNode: SchemaNode, isPatternProp: boolean, headingPrefix: string) => { metadata: any, mdContent: string };
}
