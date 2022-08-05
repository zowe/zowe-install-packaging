import $RefParser from "json-schema-ref-parser";
import { SchemasById } from "../types";
import { getSchemaById } from "../util";

export default class RefResolver implements $RefParser.ResolverOptions {

    public constructor(private schemas: SchemasById) {
    }

    public readonly order = 1;

    public readonly canRead = (ref: $RefParser.FileInfo): boolean => {
        // TODO can this result be cached? read does the same operation, canRead should always be ran before read
        const schema = getSchemaById(ref.url, this.schemas);
        return schema !== null && schema !== undefined;
    }

    // parser expects a string or buffer to be read from the file
    public readonly read = (ref: $RefParser.FileInfo): string => {
        return JSON.stringify(getSchemaById(ref.url, this.schemas));
    }
}
