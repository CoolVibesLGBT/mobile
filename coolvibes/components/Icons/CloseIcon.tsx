import React from 'react';
import { Svg, Path } from 'react-native-svg';
import { useTheme } from '@react-navigation/native';

const CloseIcon = ({ size = 24, color }: { size?: number; color?: string }) => {
  const { colors } = useTheme();
  const iconColor = color || colors.text;
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={iconColor} strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
      <Path d="M18 6L6 18" />
      <Path d="M6 6L18 18" />
    </Svg>
  );
};

export default CloseIcon;
