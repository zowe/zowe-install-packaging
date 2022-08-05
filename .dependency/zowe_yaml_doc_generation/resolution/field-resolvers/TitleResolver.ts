import FieldResolver from "./FieldResolver";

export default class TitleResolver extends FieldResolver<string> {
    public constructor() {
        super('title');
    }

    protected override internalResolve(titles: string[]) {
        const uniqueTitles = titles.reduce((acc: Set<string>, cur: string) => {
            if (cur) {
                acc.add(cur);
            }
            return acc;
        }, new Set());

        return Array.from(uniqueTitles).join('\n');
    }
};
