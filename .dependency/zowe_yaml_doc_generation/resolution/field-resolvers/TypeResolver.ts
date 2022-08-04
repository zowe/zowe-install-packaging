import FieldResolver from "./FieldResolver";

export default class TypeResolver extends FieldResolver<string> {
    private static instance: TypeResolver | null = null;

    private constructor() {
        super('type');
    }

    protected override internalResolve() { return 'object'; } // know the top level type is always object

    public static getInstance(): TypeResolver {
        if (!this.instance) {
            this.instance = new TypeResolver();
        }
        return this.instance;
    }
};
