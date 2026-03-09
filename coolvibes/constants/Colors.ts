/**
 * Premium Monochrome + Subtle Pride Accent Colors
 */

const tintColorLight = '#000000';
const tintColorDark = '#FFFFFF';

export const Colors = {
  light: {
    text: '#000000',
    background: '#FFFFFF',
    tint: tintColorLight,
    icon: '#666666',
    tabIconDefault: '#999999',
    tabIconSelected: tintColorLight,
    border: '#E8E8E8',
    secondaryBackground: '#F8F9FA',
    accent: '#000000', // Pure black accent for light mode
    accentGradient: ['#000000', '#333333'],
    card: '#FFFFFF',
    notification: '#000000',
  },
  dark: {
    text: '#FFFFFF',
    background: '#000000',
    tint: tintColorDark,
    icon: '#8E8E93',
    tabIconDefault: '#48484A',
    tabIconSelected: tintColorDark,
    border: '#2C2C2E',
    secondaryBackground: '#121212',
    accent: '#FFFFFF', // Pure white accent for dark mode
    accentGradient: ['#FFFFFF', '#CCCCCC'],
    card: '#1C1C1E',
    notification: '#FFFFFF',
  },
};
