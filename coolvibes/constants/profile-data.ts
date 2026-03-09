const t = (key: string) => key.split('.').pop()?.replace(/_/g, ' ') ?? key;

export const USER_ATTRIBUTES = [
    // Identity
    { field: 'gender_identity', label: t('profile.gender_identity'), icon: 'gender-male-female' },
    { field: 'sexual_orientation', label: t('profile.sexual_orientation'), icon: 'rainbow' },
    { field: 'sex_role', label: t('profile.sex_role'), icon: 'rabbit' },
    { field: 'preferred_partner_gender', label: t('profile.preferred_partner_gender'), icon: 'account-group-outline' },
    { field: 'relationship_status', label: t('profile.relationship_status'), icon: 'heart-outline' },
    { field: 'relationship_preferences', label: t('profile.relationship_preferences'), icon: 'heart-pulse' },
    
    // Appearance
    { field: 'height', label: t('profile.height'), icon: 'ruler' },
    { field: 'weight', label: t('profile.weight'), icon: 'scale-bathroom' },
    { field: 'body_type', label: t('profile.body_type'), icon: 'human-capacity-increase' },
    { field: 'hair_color', label: t('profile.hair_color'), icon: 'palette-outline' },
    { field: 'eye_color', label: t('profile.eye_color'), icon: 'eye-outline' },
    { field: 'skin_color', label: t('profile.skin_color'), icon: 'brush' },
    { field: 'tattoos', label: t('profile.tattoos'), icon: 'flower' },
    { field: 'ethnicity', label: t('profile.ethnicity'), icon: 'fingerprint' },
    
    // About Me
    { field: 'zodiac_sign', label: t('profile.zodiac_sign'), icon: 'zodiac-leo' },
    { field: 'circumcision', label: t('profile.circumcision'), icon: 'banana' },
    { field: 'physical_disability', label: t('profile.physical_disability'), icon: 'accessibility' },
    { field: 'smoking', label: t('profile.smoking'), icon: 'smoking' },
    { field: 'drinking', label: t('profile.drinking'), icon: 'glass-wine' },
    { field: 'religion', label: t('profile.religion'), icon: 'church' },
    { field: 'education', label: t('profile.education_level'), icon: 'school-outline' },
    { field: 'personality', label: t('profile.personality'), icon: 'drama-masks' },
    { field: 'mbti_type', label: t('profile.mbti_type'), icon: 'brain' },
    { field: 'cronotype', label: t('profile.cronotype'), icon: 'clock-outline' },
    { field: 'sense_of_humor', label: t('profile.sense_of_humor'), icon: 'emoticon-happy-outline' },
    
    // Lifestyle
    { field: 'kids_preference', label: t('profile.kids'), icon: 'baby-face-outline' },
    { field: 'pets', label: t('profile.pets'), icon: 'paw' },
    { field: 'dietary', label: t('profile.dietary'), icon: 'leaf' },
    { field: 'hiv_aids_status', label: t('profile.hiv_aids_status'), icon: 'shield-half-full' },
    
    // BDSM
    { field: 'bdsm_interest', label: t('profile.bdsm_interest'), icon: 'panda' },
    { field: 'bdsm_plays', label: t('profile.bdsm_plays'), icon: 'ghost' },
    { field: 'bdsm_roles', label: t('profile.bdsm_roles'), icon: 'comment-outline' },
];

export const ABOUT_SECTIONS = [
    { 
        title: 'Identity', 
        icon: 'account-search-outline', 
        attributes: ['gender_identity', 'sexual_orientation', 'sex_role', 'preferred_partner_gender', 'relationship_status', 'relationship_preferences'] 
    },
    { 
        title: 'Appearance', 
        icon: 'face-man-profile', 
        attributes: ['height', 'weight', 'body_type', 'hair_color', 'eye_color', 'skin_color', 'tattoos', 'ethnicity'] 
    },
    { 
        title: 'About Me', 
        icon: 'brain', 
        attributes: ['zodiac_sign', 'personality', 'mbti_type', 'cronotype', 'sense_of_humor', 'education', 'religion', 'physical_disability', 'circumcision'] 
    },
    { 
        title: 'Lifestyle', 
        icon: 'heart-cog-outline', 
        attributes: ['smoking', 'drinking', 'kids_preference', 'pets', 'dietary', 'hiv_aids_status'] 
    },
    { 
        title: 'Kink & BDSM', 
        icon: 'account-lock-outline', 
        attributes: ['bdsm_interest', 'bdsm_plays', 'bdsm_roles'] 
    },
];

export const ATTRIBUTES_MAP = USER_ATTRIBUTES.reduce((acc, attr) => {
  acc[attr.field] = attr;
  return acc;
}, {} as Record<string, typeof USER_ATTRIBUTES[0]>);
