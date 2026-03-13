export const parsePreferencesFlags = (flags: string | null | undefined): bigint => {
  if (!flags || flags === '') return BigInt(0);
  try {
    // Try parsing as hex string first
    if (flags.startsWith('0x') || /^[0-9a-fA-F]+$/.test(flags)) {
      return BigInt(flags.startsWith('0x') ? flags : `0x${flags}`);
    }
    // Try parsing as decimal
    return BigInt(flags);
  } catch {
    return BigInt(0);
  }
};

export const serializePreferencesFlags = (flags: bigint): string => {
  if (flags === BigInt(0)) return '';
  return flags.toString(16);
};

export const isBitSet = (flags: bigint, bitIndex: number): boolean => {
  return (flags & (BigInt(1) << BigInt(bitIndex))) !== BigInt(0);
};

export const setBit = (flags: bigint, bitIndex: number): bigint => {
  return flags | (BigInt(1) << BigInt(bitIndex));
};

export const unsetBit = (flags: bigint, bitIndex: number): bigint => {
  return flags & ~(BigInt(1) << BigInt(bitIndex));
};

export const toggleBit = (flags: bigint, bitIndex: number): bigint => {
  return isBitSet(flags, bitIndex) ? unsetBit(flags, bitIndex) : setBit(flags, bitIndex);
};
