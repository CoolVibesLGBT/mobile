import React from 'react';
import { Svg, Path, Polyline } from 'react-native-svg';
import { useTheme } from '@react-navigation/native';

const RewindIcon = ({ size = 24, color }: { size?: number; color?: string }) => {
  const { colors } = useTheme();
  const iconColor = color || colors.text;
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={iconColor} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <Polyline points="23 4 23 10 17 10" />
      <Path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10" />
    </Svg>
  );
};

export default RewindIcon;