export const calculateAge = (dateOfBirth: string): number | null => {
    if (!dateOfBirth) {
        return null;
    }
    const birthDate = new Date(dateOfBirth);
    const today = new Date();
    let age = today.getFullYear() - birthDate.getFullYear();
    const m = today.getMonth() - birthDate.getMonth();
    if (m < 0 || (m === 0 && today.getDate() < birthDate.getDate())) {
        age--;
    }
    return age;
};

export const getSafeImageURL = (url: string | undefined | null, defaultUrl: string = 'https://picsum.photos/900/900?grayscale'): string => {
    if (url) {
        return url;
    }
    return defaultUrl;
};
