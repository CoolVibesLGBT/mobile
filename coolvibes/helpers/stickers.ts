export type StickerAsset = {
  id: string;
  label: string;
  fileName: string;
  path: string;
  url: string;
  category: 'cats' | 'valentines' | 'monkeys';
};

export const STICKER_BASE_URL = 'https://coolvibes.lgbt/stickers';
export const STICKER_PUBLIC_PATH = '/stickers';

const buildSticker = (
  fileName: string,
  label: string,
  category: StickerAsset['category'],
): StickerAsset => ({
  id: fileName.replace(/\.png$/i, ''),
  label,
  fileName,
  path: `${STICKER_PUBLIC_PATH}/${fileName}`,
  url: `${STICKER_BASE_URL}/${fileName}`,
  category,
});

const buildRange = (
  prefix: string,
  count: number,
  labelPrefix: string,
  category: StickerAsset['category'],
) => Array.from({ length: count }, (_, index) => {
  const itemNumber = index + 1;
  return buildSticker(`${prefix}_${itemNumber}.png`, `${labelPrefix} ${itemNumber}`, category);
});

export const STICKER_ASSETS: StickerAsset[] = [
  ...buildRange('cat', 20, 'Cat', 'cats'),
  ...buildRange('cat_valentines_day', 19, 'Valentine Cat', 'valentines'),
  ...buildRange('monkey', 20, 'Monkey', 'monkeys'),
];
