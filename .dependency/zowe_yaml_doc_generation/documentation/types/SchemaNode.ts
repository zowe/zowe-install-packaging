import { Schema } from "../../types/Schema";
import { SchemaNodeMetadata } from "./SchemaNodeMetadata";

export type SchemaNode = {
    schema: Schema;
    metadata: SchemaNodeMetadata;
};
