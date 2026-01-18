export function LocalizedStringToString(
    localizedString: any,
    locale: string = 'en'
): string {
    locale = locale || 'en';
    if (!localizedString) return '';

    if (typeof localizedString === 'string') {
        return localizedString;
    }

    if (typeof localizedString === 'object') {
        if (localizedString[locale]) {
            return localizedString[locale];
        }
        if (localizedString.en) {
            return localizedString.en;
        }
        const first = Object.values(localizedString).find(
            v => typeof v === 'string'
        );
        if (first) return first;
    }
    return '';
}