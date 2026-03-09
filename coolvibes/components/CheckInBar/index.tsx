
import React, { useMemo, memo } from 'react';
import { View, Text, StyleSheet, Pressable, Dimensions, TouchableOpacity } from 'react-native';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  interpolate,
  Extrapolation,
  withSpring,
} from 'react-native-reanimated';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import * as Haptics from 'expo-haptics';
import { useAppSelector } from '@/store/hooks';
import { LocalizedStringToString } from '@/utils/utils';
import { useTheme } from '@react-navigation/native';

// --- CONFIGURATION & DIMENSIONS ---
const { width: SCREEN_WIDTH } = Dimensions.get('window');
const HEX_SIZE = 100;
const CENTER_X = SCREEN_WIDTH / 2;
const CENTER_Y = 250; // Dynamic enough for full screen
const ITEM_DIM = 140;
const OFFSET = ITEM_DIM / 2;

const axialToPixel = (q: number, r: number) => {
  'worklet';
  return {
    x: HEX_SIZE * (Math.sqrt(3) * q + (Math.sqrt(3) / 2) * r),
    y: HEX_SIZE * (1.5 * r),
  };
};

const HexItem = memo(({ authUser, tag, q, r, panX, panY, isSelected, onSelect }: any) => {
  const { colors } = useTheme();
  const { x, y } = axialToPixel(q, r);
  const iconName = tag.icon;
  
  const style = useAnimatedStyle(() => {
    const px = x + panX.value;
    const py = y + panY.value;
    const dist = Math.sqrt(px * px + py * py);

    const scale = interpolate(dist, [0, 80, 400], [1.6, 1.0, 0.5], Extrapolation.CLAMP);
    const opacity = interpolate(dist, [0, 250, 450], [1, 0.8, 0.05], Extrapolation.CLAMP);

    return {
      transform: [
        { translateX: px + CENTER_X - OFFSET },
        { translateY: py + CENTER_Y - OFFSET },
        { scale: withSpring(scale, { damping: 20, stiffness: 90 }) }
      ] as any,
      opacity,
      zIndex: Math.round(1000 - dist),
    };
  });

  return (
    <Animated.View style={[styles.hexWrap, style]}>
      <Pressable
        onPress={() => onSelect(tag.tag, x, y)}
        style={({ pressed }) => [
          styles.hexBtn,
          { 
            backgroundColor: isSelected ? colors.primary : colors.card,
            borderColor: isSelected ? colors.primary : colors.border,
            borderWidth: 1.5,
          },
          pressed && styles.pressedBtn
        ]}
      >
        <MaterialCommunityIcons
          name={iconName}
          size={isSelected ? 34 : 28}
          color={isSelected ? colors.background : colors.text}
        />
        {isSelected && (
          <View style={[styles.selectedIndicator, { backgroundColor: colors.background }]} />
        )}
      </Pressable>
      <Text style={[
        styles.hexText, 
        { color: colors.text, opacity: isSelected ? 1 : 0.6, fontFamily: isSelected ? 'Inter-Bold' : 'Inter-SemiBold' },
      ]}>
        {LocalizedStringToString(tag.name, authUser?.default_language)}
      </Text>
    </Animated.View>
  );
});

interface CheckInRadarProps {
  selectedTags: string[];
  onSelectTag: (tag: string) => void;
  onClearTags: () => void;
}

export function CheckInRadar({ selectedTags, onSelectTag, onClearTags }: CheckInRadarProps) {
  const { data } = useAppSelector(state => state.system);
  const authUser = useAppSelector(state => state.auth.user);
  const { colors, dark } = useTheme();
  
  const panX = useSharedValue(0);
  const panY = useSharedValue(0);
  const startX = useSharedValue(0);
  const startY = useSharedValue(0);

  const honeycomb = useMemo(() => {
    if (!data?.checkin_tag_types) return [];
    
    const count = data.checkin_tag_types.length;
    const results: { q: number; r: number }[] = [{ q: 0, r: 0 }];
    const directions = [
      { q: 1, r: 0 }, { q: 1, r: -1 }, { q: 0, r: -1 },
      { q: -1, r: 0 }, { q: -1, r: 1 }, { q: 0, r: 1 },
    ];

    let radius = 1;
    while (results.length < count) {
      let q = directions[4].q * radius;
      let r = directions[4].r * radius;
      for (let side = 0; side < 6; side++) {
        for (let step = 0; step < radius; step++) {
          if (results.length < count) results.push({ q, r });
          q += directions[side].q;
          r += directions[side].r;
        }
      }
      radius++;
    }

    return data.checkin_tag_types.map((tag, idx) => ({
      tag,
      q: results[idx].q,
      r: results[idx].r,
      id: `hex-${idx}-${tag.tag}`
    }));
  }, [data]);

  const snapToCenter = (targetX: number, targetY: number) => {
    panX.value = withSpring(-targetX, { damping: 20, stiffness: 100 });
    panY.value = withSpring(-targetY, { damping: 20, stiffness: 100 });
  };

  const handleItemPress = (tag: string, x: number, y: number) => {
    snapToCenter(x, y);
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    onSelectTag(tag);
  };

  const gesture = Gesture.Pan()
    .onBegin(() => {
      startX.value = panX.value;
      startY.value = panY.value;
    })
    .onUpdate(e => {
      panX.value = startX.value + e.translationX;
      panY.value = startY.value + e.translationY;
    })
    .onEnd((e) => {
      'worklet';
      const predictedX = panX.value + e.velocityX * 0.1;
      const predictedY = panY.value + e.velocityY * 0.1;
      let minDist = Infinity;
      let targetX = 0;
      let targetY = 0;
      for (let i = 0; i < honeycomb.length; i++) {
        const h = honeycomb[i];
        const p = axialToPixel(h.q, h.r);
        const d = Math.pow(p.x + predictedX, 2) + Math.pow(p.y + predictedY, 2);
        if (d < minDist) {
          minDist = d;
          targetX = p.x;
          targetY = p.y;
        }
      }
      panX.value = withSpring(-targetX, { damping: 18, stiffness: 90, velocity: e.velocityX });
      panY.value = withSpring(-targetY, { damping: 18, stiffness: 90, velocity: e.velocityY });
    });

  return (
    <View style={styles.radarWrapper}>
      <GestureDetector gesture={gesture}>
        <View style={styles.radarViewport}>
          {/* Tactical Background Rings */}
          <View style={[styles.radarRing, { width: 140, height: 140, left: CENTER_X - 70, top: CENTER_Y - 70, borderColor: colors.border }]} pointerEvents="none" />
          <View style={[styles.radarRing, { width: 300, height: 300, left: CENTER_X - 150, top: CENTER_Y - 150, borderColor: colors.border, opacity: 0.5 }]} pointerEvents="none" />
          <View style={[styles.radarRing, { width: 460, height: 460, left: CENTER_X - 230, top: CENTER_Y - 230, borderColor: colors.border, opacity: 0.2, borderStyle: 'dashed' }]} pointerEvents="none" />

          {honeycomb.map((item) => (
            <HexItem
              authUser={authUser}
              key={item.id}
              {...item}
              panX={panX}
              panY={panY}
              isSelected={selectedTags.includes(item.tag.tag)}
              onSelect={handleItemPress}
            />
          ))}

          {/* Crosshair Overlay */}
          <View style={[styles.crosshairContainer, { left: CENTER_X - 175, top: CENTER_Y - 175 }]} pointerEvents="none">
            <View style={[styles.crossLineV, { backgroundColor: colors.primary, height: 40, width: 1, opacity: 0.4 }]} />
            <View style={[styles.crossLineH, { backgroundColor: colors.primary, width: 40, height: 1, opacity: 0.4 }]} />
            <View style={[styles.diagonalLine, { transform: [{ rotate: '45deg' }], backgroundColor: colors.primary, opacity: 0.05 }]} />
            <View style={[styles.diagonalLine, { transform: [{ rotate: '-45deg' }], backgroundColor: colors.primary, opacity: 0.05 }]} />
          </View>
        </View>
      </GestureDetector>

      {selectedTags.length > 0 && (
        <View style={[styles.vibeStatus, { backgroundColor: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.05)' }]}>
          <Text style={[styles.vibeStatusText, { color: colors.text }]}>
            <Text style={{ fontFamily: 'Outfit-Black' }}>{selectedTags.length}</Text> VIBE SELECTED
          </Text>
          <TouchableOpacity onPress={onClearTags} style={styles.resetBtn} activeOpacity={0.7}>
            <MaterialCommunityIcons name="refresh" size={14} color={colors.primary} />
            <Text style={[styles.resetText, { color: colors.primary }]}>RESET</Text>
          </TouchableOpacity>
        </View>
      )}
    </View>
  );
}

// Direct screen usage support
export const CheckIn = CheckInRadar;

const styles = StyleSheet.create({
  radarWrapper: { flex: 1, width: '100%', backgroundColor: 'transparent' },
  radarViewport: { 
    position: "relative", 
    flex: 1, 
    width: '100%', 
    justifyContent: 'center', 
    alignItems: 'center', 
    overflow: 'hidden' 
  },
  hexWrap: { 
    position: 'absolute', 
    left: 0, 
    top: 0, 
    width: ITEM_DIM, 
    height: ITEM_DIM, 
    alignItems: 'center', 
    justifyContent: 'center' 
  },
  hexBtn: {
    width: 76, 
    height: 76, 
    borderRadius: 38,
    alignItems: 'center', 
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.15,
    shadowRadius: 10,
    elevation: 8
  },
  pressedBtn: { transform: [{ scale: 0.92 }], opacity: 0.85 },
  selectedIndicator: {
    position: 'absolute',
    bottom: -6,
    width: 6,
    height: 6,
    borderRadius: 3,
  },
  hexText: { 
    fontSize: 9, 
    textAlign: 'center', 
    marginTop: 8, 
    letterSpacing: 0.5,
    textTransform: 'uppercase'
  },
  crosshairContainer: { 
    position: 'absolute', 
    width: 350, 
    height: 350, 
    alignItems: 'center', 
    justifyContent: 'center' 
  },
  crossLineV: { position: 'absolute' },
  crossLineH: { position: 'absolute' },
  diagonalLine: { position: 'absolute', width: 200, height: 1 },
  radarRing: { position: 'absolute', borderRadius: 999, borderWidth: 1 },
  vibeStatus: {
    position: 'absolute',
    bottom: 20,
    alignSelf: 'center',
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(0,0,0,0.05)',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
  },
  vibeStatusText: {
    fontSize: 10,
    fontFamily: 'Inter-Bold',
    letterSpacing: 1,
    marginRight: 10
  },
  resetBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    borderLeftWidth: 1,
    borderLeftColor: 'rgba(0,0,0,0.1)',
    paddingLeft: 10
  },
  resetText: {
    fontSize: 9,
    fontFamily: 'Inter-Bold',
    marginLeft: 4
  }
});