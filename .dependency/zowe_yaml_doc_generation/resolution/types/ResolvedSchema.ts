import { JSONSchema } from "json-schema-ref-parser";

// json-schema-ref-parser doesn't have some draft19-09 keywords
type ResolvedSchema = {
    $defs: any;
    $anchor: string;
} & JSONSchema;

export default ResolvedSchema;
