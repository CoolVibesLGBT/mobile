/**
 * Learn more about light and dark modes:
 * https://docs.expo.dev/guides/color-schemes/
 */

import { Colors } from '@/constants/Colors';
import { useColorScheme } from '@/hooks/use-color-scheme';

export function useThemeColor(
  props: { light?: string; dark?: string },
  colorName: { [K in keyof typeof Colors.light]: typeof Colors.light[K] extends string ? K : never }[keyof typeof Colors.light] &
             { [K in keyof typeof Colors.dark]: typeof Colors.dark[K] extends string ? K : never }[keyof typeof Colors.dark]
) {
  const theme = useColorScheme() ?? 'light';
  const colorFromProps = props[theme];

  if (colorFromProps) {
    return colorFromProps;
  } else {
    return Colors[theme][colorName];
  }
}
