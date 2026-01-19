const t = (key: string) => key.split('.').pop()?.replace(/_/g, ' ') ?? key;

export const USER_ATTRIBUTES = [
    { field: 'gender_identity', label: t('profile.gender_identity'), icon: 'gender-male-female' },
    { field: 'sexual_orientation', label: t('profile.sexual_orientation'), icon: 'rainbow' },
    { field: 'relationship_status', label: t('profile.relationship_status'), icon: 'handshake-outline' },
    { field: 'height', label: t('profile.height'), icon: 'ruler' },
    { field: 'body_type', label: t('profile.body_type'), icon: 'arm-flex-outline' },
    { field: 'zodiac_sign', label: t('profile.zodiac_sign'), icon: 'zodiac-leo' },
    { field: 'smoking', label: t('profile.smoking'), icon: 'smoking' },
    { field: 'drinking', label: t('profile.drinking'), icon: 'glass-wine' },
    { field: 'education', label: t('profile.education_level'), icon: 'school-outline' },
    { field: 'personality', label: t('profile.personality'), icon: 'psychology-outline' },
];

export const ABOUT_SECTIONS = [
    { title: 'Identity', icon: 'account-search-outline', attributes: ['gender_identity', 'sexual_orientation', 'relationship_status'] },
    { title: 'Appearance', icon: 'face-man-profile', attributes: ['height', 'body_type',] },
    { title: 'Lifestyle', icon: 'brain', attributes: ['zodiac_sign', 'smoking', 'drinking', 'education', 'personality'] },
];

export const ATTRIBUTES_MAP = USER_ATTRIBUTES.reduce((acc, attr) => {
  acc[attr.field] = attr;
  return acc;
}, {} as Record<string, typeof USER_ATTRIBUTES[0]>);
