import $RefParser from "json-schema-ref-parser";
import { ResolvedSchema } from "../types";

export default class SchemaParser implements $RefParser.ParserOptions {
    public readonly order = 1;
    public readonly canParse = '.json';

    public readonly parse = (file: $RefParser.FileInfo): ResolvedSchema => {
        // This is the file being referenced by the schema that is getting dereferenced.
        // Resolver can't handle anchors and some path syntax used (e.g. requires $defs in the path), and can't see the path/anchor so
        // custom resolver can't fix. So, this will take any $defs and put them top level, and
        // make a duplicate object with key for the real name and a key for the anchor

        let parsedSchema: ResolvedSchema = JSON.parse(file.data.toString());
        if (parsedSchema?.$defs) {
            const defs = parsedSchema.$defs;
            const anchoredDefs = Object.entries<ResolvedSchema>(defs).reduce<{ [k: string]: ResolvedSchema }>((obj, [_, defValue]) => {
                if (defValue.$anchor) {
                    obj[defValue.$anchor] = defValue;
                }
                return obj;
            }, {});

            parsedSchema.$defs = { ...defs, ...anchoredDefs };
        }
        return parsedSchema;
    }
}
