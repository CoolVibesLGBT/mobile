export type TagGradient = {
  colors: [string, string];
  textColor: string;
};

const TAG_GRADIENTS: TagGradient[] = [
  { colors: ['#FF3B30', '#FF6B3B'], textColor: '#ffffff' },
  { colors: ['#FF453A', '#FF7A45'], textColor: '#ffffff' },
  { colors: ['#FF6B6B', '#FF3B30'], textColor: '#ffffff' },
  { colors: ['#FF9500', '#FFD60A'], textColor: '#1f2937' },
  { colors: ['#FF9F0A', '#FFCC00'], textColor: '#1f2937' },
  { colors: ['#FFD60A', '#FF9500'], textColor: '#1f2937' },
  { colors: ['#FFD60A', '#34C759'], textColor: '#1f2937' },
  { colors: ['#FFE066', '#30D158'], textColor: '#1f2937' },
  { colors: ['#34C759', '#32D74B'], textColor: '#ffffff' },
  { colors: ['#30D158', '#66E27F'], textColor: '#ffffff' },
  { colors: ['#007AFF', '#5AC8FA'], textColor: '#ffffff' },
  { colors: ['#0A84FF', '#64D2FF'], textColor: '#ffffff' },
  { colors: ['#5AC8FA', '#007AFF'], textColor: '#ffffff' },
  { colors: ['#5856D6', '#5E5CE6'], textColor: '#ffffff' },
  { colors: ['#6E6BE8', '#5856D6'], textColor: '#ffffff' },
  { colors: ['#AF52DE', '#FF2D55'], textColor: '#ffffff' },
  { colors: ['#BF5AF2', '#FF375F'], textColor: '#ffffff' },
  { colors: ['#DA77F2', '#FF2D55'], textColor: '#ffffff' },
];

function stringToSeed(str: string): number {
  const safe = typeof str === 'string' ? str : String(str ?? '');
  let hash = 0;
  for (let i = 0; i < safe.length; i++) {
    hash = (hash << 5) - hash + safe.charCodeAt(i);
    hash |= 0;
  }
  return Math.abs(hash);
}

export function getTagGradient(seed: string): TagGradient {
  const index = stringToSeed(seed) % TAG_GRADIENTS.length;
  return TAG_GRADIENTS[index];
}

