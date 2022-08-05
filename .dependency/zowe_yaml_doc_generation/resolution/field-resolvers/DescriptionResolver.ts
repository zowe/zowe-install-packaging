import FieldResolver from "./FieldResolver";

export default class DescriptionResolver extends FieldResolver<string> {
    public constructor() {
        super('description');
    }

    // TODO DRY with TitleResolver
    protected override internalResolve(descriptionValues: string[]) {
        const uniqueTitles = descriptionValues.reduce((acc: Set<string>, cur: string) => {
            if (cur) {
                acc.add(cur);
            }
            return acc;
        }, new Set());

        return Array.from(uniqueTitles).join('\n');
    }
};
