import FieldResolver from "./FieldResolver";

export default class TypeResolver extends FieldResolver<string> {
    public constructor() {
        super('type');
    }

    protected override internalResolve() { return 'object'; } // know the top level type is always object TODO but if this is recursive then no? How to resolve?
};
