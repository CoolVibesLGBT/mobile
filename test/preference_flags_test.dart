import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/components/profile_about.dart';

void main() {
  test('hex preferences_flags decode like helpers/bitfield.ts', () {
    final flags = parsePreferencesFlags('5');
    expect(isBitSet(flags, 0), isTrue);
    expect(isBitSet(flags, 1), isFalse);
    expect(isBitSet(flags, 2), isTrue);
    // Bits far beyond 64 need BigInt, as interests use bit_index ~510.
    final wide = setBit(BigInt.zero, 510);
    expect(isBitSet(parsePreferencesFlags(serializePreferencesFlags(wide)), 510), isTrue);
  });
  test('selected_preference_bits wins over preferences_flags', () {
    final flags = preferenceFlagsOf({'selected_preference_bits': [0, 510], 'preferences_flags': 'ff'});
    expect(isBitSet(flags, 0), isTrue);
    expect(isBitSet(flags, 1), isFalse);
    expect(isBitSet(flags, 510), isTrue);
  });
}
