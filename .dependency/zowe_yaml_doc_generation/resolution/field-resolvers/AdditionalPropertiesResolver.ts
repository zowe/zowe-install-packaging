import FieldResolver from "./FieldResolver";

export default class AdditionalPropertiesResolver extends FieldResolver<boolean> {
    public constructor() {
        super('additionalProperties');
    }

    protected override internalResolve(additionalPropertiesValues: boolean[]) {
        // if one does not allow additional properties, then result is no further properties are allowed
        return !additionalPropertiesValues.find(ap => !ap);
    }
};
