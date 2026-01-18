import React from 'react';
import { Svg, Path } from 'react-native-svg';
import { useTheme } from '@react-navigation/native';

const DislikeIcon = ({ size = 24, color }: { size?: number; color?: string }) => {
  const { colors } = useTheme();
  const iconColor = color || colors.text;
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={iconColor} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <Path d="M18 6L6 18M6 6l12 12" />
    </Svg>
  );
};

export default DislikeIcon;