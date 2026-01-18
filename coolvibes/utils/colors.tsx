import { ColorValue } from "react-native";

type RankGradient = {
  colors: readonly [ColorValue, ColorValue];
  textColor: ColorValue;
};


const rainbowRankGradients: readonly RankGradient[] = [
  { colors: ['#FF3B30', '#FF6B3B'], textColor: '#fff' },
  { colors: ['#FF9500', '#FFD60A'], textColor: '#fff' },
  { colors: ['#FFD60A', '#34C759'], textColor: '#fff' },
  { colors: ['#34C759', '#32D74B'], textColor: '#fff' },
  { colors: ['#007AFF', '#5AC8FA'], textColor: '#fff' },
  { colors: ['#5856D6', '#5E5CE6'], textColor: '#fff' },
  { colors: ['#AF52DE', '#FF2D55'], textColor: '#fff' },
];

function hslToHex(h: number, s: number, l: number): string {
  s /= 100;
  l /= 100;

  const k = (n: number) => (n + h / 30) % 12;
  const a = s * Math.min(l, 1 - l);
  const f = (n: number) =>
    l - a * Math.max(-1, Math.min(k(n) - 3, Math.min(9 - k(n), 1)));

  const toHex = (x: number) =>
    Math.round(255 * x)
      .toString(16)
      .padStart(2, '0');

  return `#${toHex(f(0))}${toHex(f(8))}${toHex(f(4))}`;
}

const hashStringToNumber = (str: string): number => {
  let hash = 0;

  for (let i = 0; i < str.length; i++) {
    hash = (hash << 5) - hash + str.charCodeAt(i);
    hash |= 0;
  }

  return Math.abs(hash);
};



export const getRankGradient = (tag: string | number): RankGradient => {
  // number gelirse eski davranış
  if (typeof tag === 'number') {
    const index = Math.max(0, tag - 1) % rainbowRankGradients.length;
    return rainbowRankGradients[index];
  }

  // string (tag) gelirse
  const hash = hashStringToNumber(tag);
  const index = hash % rainbowRankGradients.length;

  return rainbowRankGradients[index];
};