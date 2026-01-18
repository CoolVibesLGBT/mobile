
import React, { useMemo, useState, memo, useCallback } from 'react';
import { View, Text, StyleSheet, Pressable, Dimensions, TextInput, ScrollView, KeyboardAvoidingView, Platform, Alert, Keyboard } from 'react-native';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  interpolate,
  Extrapolation,
  withSpring,
  useDerivedValue,
} from 'react-native-reanimated';
import { Gesture, GestureDetector, GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaView } from 'react-native-safe-area-context';
import ChatInput from '../ChatInput';
import * as Haptics from 'expo-haptics';
import { useAppSelector } from '@/store/hooks';
import { LocalizedStringToString } from '@/utils/utils';

// --- CONFIGURATION & DIMENSIONS ---
const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');
const HEX_SIZE = 100;
const RADAR_HEIGHT = SCREEN_HEIGHT / 2;
const CENTER_X = SCREEN_WIDTH / 2;
const CENTER_Y = RADAR_HEIGHT / 2;
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
  const { x, y } = axialToPixel(q, r);
  const iconName = tag.icon
  const style = useAnimatedStyle(() => {
    const px = x + panX.value;
    const py = y + panY.value;
    const dist = Math.sqrt(px * px + py * py);

    // Dynamic scale based on proximity to center
    // Centered item gets a scale of 1.8x, others fade to 0.4x
    const scale = interpolate(dist, [0, 100, 450], [1.8, 1.0, 0.4], Extrapolation.CLAMP);
    const opacity = interpolate(dist, [0, 220, 500], [1, 0.9, 0.05], Extrapolation.CLAMP);
    const isVeryClose = dist < 40;

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
        onPress={() => onSelect(tag, x, y)}
        style={({ pressed }) => [
          styles.hexBtn,
          isSelected && styles.selectedBtn,
          pressed && styles.pressedBtn
        ]}
      >
        <MaterialCommunityIcons
          name={iconName}
          size={isSelected ? 32 : 28}
          color={isSelected ? '#fff' : '#64748B'}
        />
        <Text style={[styles.hexText, isSelected && { color: '#fff' }]}>
          {LocalizedStringToString(tag.name, authUser?.default_language)}
        </Text>

        {isSelected && (
          <View style={styles.selectedBadge}>
            <MaterialCommunityIcons name="check" size={12} color="white" />
          </View>
        )}
      </Pressable>
    </Animated.View>
  );
});

export function CheckIn() {
  const [selectedFilters, setSelectedFilters] = useState<string[]>([]);
  const { loading, error, data } = useAppSelector(state => state.system);
  const authUser = useAppSelector(state => state.auth.user);
  // Shared values for high-performance interaction
  const panX = useSharedValue(0);
  const panY = useSharedValue(0);
  const startX = useSharedValue(0);
  const startY = useSharedValue(0);



  function generateInfiniteHexCoords(count: number) {
    const results: { q: number; r: number }[] = [];

    // merkez
    results.push({ q: 0, r: 0 });

    if (count === 1) return results;

    const directions = [
      { q: 1, r: 0 },
      { q: 1, r: -1 },
      { q: 0, r: -1 },
      { q: -1, r: 0 },
      { q: -1, r: 1 },
      { q: 0, r: 1 },
    ];

    let radius = 1;

    while (results.length < count) {
      let q = directions[4].q * radius;
      let r = directions[4].r * radius;

      for (let side = 0; side < 6; side++) {
        for (let step = 0; step < radius; step++) {
          if (results.length >= count) return results;

          results.push({ q, r });
          q += directions[side].q;
          r += directions[side].r;
        }
      }

      radius++;
    }

    return results;
  }

  // Layout logic: Each tag gets a unique hex coordinate (no duplicates)
  const honeycomb = useMemo(() => {
    if (!data?.checkin_tag_types) return [];
    const coords = generateInfiniteHexCoords(
      data?.checkin_tag_types.length
    );
    return data?.checkin_tag_types?.map((tag, idx) => ({
      tag: tag,
      q: coords[idx].q,
      r: coords[idx].r,
      id: `hex-${idx}{${tag.tag}`
    }));
  }, []);

  const snapToCenter = (targetX: number, targetY: number) => {
    panX.value = withSpring(-targetX, { damping: 18, stiffness: 100 });
    panY.value = withSpring(-targetY, { damping: 18, stiffness: 100 });
  };

  const handleItemPress = (tag: string, x: number, y: number) => {
    snapToCenter(x, y);
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);

    setSelectedFilters(prev =>
      prev.includes(tag) ? prev.filter(t => t !== tag) : [...prev, tag]
    );
  };

  // Magnet / Snapping gesture logic
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
      // Inertia-based snapping calculation
      const predictedX = panX.value + e.velocityX * 0.12;
      const predictedY = panY.value + e.velocityY * 0.12;

      let minDist = Infinity;
      let targetX = 0;
      let targetY = 0;

      // Find the item that will be closest to the center after inertia
      for (let i = 0; i < honeycomb.length; i++) {
        const h = honeycomb[i];
        const p = axialToPixel(h.q, h.r);
        const px = p.x + predictedX;
        const py = p.y + predictedY;
        const d = px * px + py * py;
        if (d < minDist) {
          minDist = d;
          targetX = p.x;
          targetY = p.y;
        }
      }

      panX.value = withSpring(-targetX, { damping: 18, stiffness: 90, velocity: e.velocityX });
      panY.value = withSpring(-targetY, { damping: 18, stiffness: 90, velocity: e.velocityY });
    });




  const handleSendMessage = (text: string, media: any[], replyToId?: string, editingId?: string) => {

    // Handle new message
    const newMessage: any = {
      id: Date.now().toString(),
      sender: "me",
      text: text,
      timestamp: new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }),
      status: "sent",
      media: media,
    };



  }


  return (
    <>
      <GestureHandlerRootView style={{ flex: 1 }}>
        <Pressable
          style={{ flex: 1 }}
          onPress={Keyboard.dismiss}
        >
          <View style={styles.radarWrapper}>
            <View style={styles.radarHud}>
              <Text style={styles.hudTitle}>Check In</Text>
              <Text style={styles.hudLabel}>Stories from Rainbow</Text>

            </View>

            <GestureDetector gesture={gesture}>
              <View style={styles.radarViewport}>
                {/* Radar Grid Circles */}
                <View style={[styles.radarRing, { width: 200, height: 200, left: CENTER_X - 100, top: CENTER_Y - 100 }]} pointerEvents="none" />
                <View style={[styles.radarRing, { width: 400, height: 400, left: CENTER_X - 200, top: CENTER_Y - 200 }]} pointerEvents="none" />
                <View style={[styles.radarRing, { width: 600, height: 600, left: CENTER_X - 300, top: CENTER_Y - 300, opacity: 0.2 }]} pointerEvents="none" />

                {honeycomb.map((item) => (
                  <HexItem
                    authUser={authUser}
                    key={item.id}
                    {...item}
                    panX={panX}
                    panY={panY}
                    isSelected={selectedFilters.includes(item.tag)}
                    onSelect={handleItemPress}
                  />
                ))}

                {/* Fixed Crosshair (Magnet Point) */}
                <View style={[styles.crosshairContainer, { left: CENTER_X - 170, top: CENTER_Y - 170 }]} pointerEvents="none">
                  <View style={styles.crossLineV} />
                  <View style={styles.crossLineH} />
                  <View style={styles.centerPulse} />
                </View>
              </View>
            </GestureDetector>

            {selectedFilters.length > 0 && (
              <Pressable onPress={() => setSelectedFilters([])} style={styles.clearBtn}>
                <View style={styles.clearBadge}>
                  <Text style={styles.clearBadgeText}>{selectedFilters.length}</Text>
                </View>
                <Text style={styles.clearLabel}>TEMİZLE</Text>
              </Pressable>
            )}
          </View>
        </Pressable>


      </GestureHandlerRootView>
      <KeyboardAvoidingView style={{position:"absolute",left:0,right:0,bottom:0 }} keyboardVerticalOffset={0} behavior={Platform.OS === "ios" ? "padding" : undefined}>
        <ChatInput
          currentUser={null}
          onSendMessage={() => handleSendMessage}
          replyingTo={null}
          onCancelReply={() => null}
          editingMessage={null}
          onCancelEdit={() => null}
        />

      </KeyboardAvoidingView>

    </>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: '#F8FAFC' },
  header: { paddingTop: 60, paddingHorizontal: 20, zIndex: 100 },
  searchBar: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'white',
    borderRadius: 28,
    height: 64,
    paddingHorizontal: 18,
    shadowColor: "#000",
    shadowOpacity: 0.05,
    shadowRadius: 15,
    elevation: 4,
    borderWidth: 1,
    borderColor: '#F1F5F9',
  },
  searchInput: { flex: 1, fontSize: 16, fontWeight: '700', color: '#1E293B', marginLeft: 12 },
  filterToggle: { width: 44, height: 44, borderRadius: 16, backgroundColor: '#F8FAFC', alignItems: 'center', justifyContent: 'center' },
  radarWrapper: { flex: 1, flexShrink: 0 },
  radarHud: { width: '100%', alignItems: 'center', zIndex: 10 },
  hudLabel: { fontSize: 10, fontWeight: '900', color: '#94A3B8', letterSpacing: 4 },
  hudTitle: { fontSize: 26, fontWeight: '900', color: '#0F172A', fontStyle: 'italic' },
  radarViewport: { position: "relative", minHeight: RADAR_HEIGHT, flex: 1, justifyContent: 'center', alignItems: 'center', overflow: 'hidden' },
  hexWrap: { position: 'absolute', left: 0, top: 0, width: ITEM_DIM, height: ITEM_DIM, alignItems: 'center', justifyContent: 'center' },
  hexBtn: {
    width: 96, height: 96, borderRadius: 48, backgroundColor: 'white',
    alignItems: 'center', justifyContent: 'center', borderWidth: 1.5, borderColor: '#F1F5F9',
    shadowColor: "#000", shadowOpacity: 0.1, shadowRadius: 12, elevation: 6
  },
  selectedBtn: { backgroundColor: '#E11D48', borderColor: '#E11D48' },
  pressedBtn: { transform: [{ scale: 0.95 }], opacity: 0.8 },
  selectedBadge: {
    position: 'absolute', top: -4, right: -4, width: 28, height: 28,
    borderRadius: 14, backgroundColor: '#E11D48', borderWidth: 3, borderColor: 'white',
    alignItems: 'center', justifyContent: 'center', zIndex: 100
  },
  hexText: { fontSize: 7.5, fontWeight: '900', textAlign: 'center', marginTop: 6, color: '#64748B', paddingHorizontal: 10 },
  crosshairContainer: { position: 'absolute', width: 340, height: 340, alignItems: 'center', justifyContent: 'center' },
  crossLineV: { position: 'absolute', width: 2, height: 48, backgroundColor: 'rgba(225,29,72,0.4)' },
  crossLineH: { position: 'absolute', width: 48, height: 2, backgroundColor: 'rgba(225,29,72,0.4)' },
  centerPulse: { width: 300, height: 300, borderRadius: 150, borderWidth: 2, borderColor: 'rgba(225,29,72,0.04)' },
  radarRing: { position: 'absolute', borderRadius: 999, borderWidth: 1, borderColor: 'rgba(0,0,0,0.03)' },
  clearBtn: {
    position: 'absolute', bottom: 25, alignSelf: 'center', flexDirection: 'row', alignItems: 'center',
    backgroundColor: '#1E293B', paddingHorizontal: 20, paddingVertical: 12, borderRadius: 32,
    shadowColor: "#000", shadowOpacity: 0.3, shadowRadius: 20, elevation: 10, zIndex: 200
  },
  clearBadge: { backgroundColor: '#E11D48', width: 22, height: 22, borderRadius: 11, alignItems: 'center', justifyContent: 'center', marginRight: 10 },
  clearBadgeText: { color: 'white', fontSize: 11, fontWeight: 'bold' },
  clearLabel: { color: 'white', fontSize: 10, fontWeight: '900', letterSpacing: 2 },
  feedPanel: {
    flex: 1, backgroundColor: 'white', borderTopLeftRadius: 44, borderTopRightRadius: 44,
    padding: 24, marginTop: -24, shadowColor: "#000", shadowOpacity: 0.08, shadowRadius: 25, elevation: 20
  },
  feedHeader: { marginBottom: 20 },
  feedStatus: { flexDirection: 'row', alignItems: 'center' },
  pulseDot: { width: 10, height: 10, borderRadius: 5, backgroundColor: '#E11D48', marginRight: 10 },
  matchCount: { fontSize: 22, fontWeight: '900', color: '#0F172A', fontStyle: 'italic' },
  feedMetaData: { fontSize: 9, fontWeight: '800', color: '#94A3B8', letterSpacing: 3, marginTop: 4 },
  feedList: { paddingBottom: 60 },
  userCard: { backgroundColor: '#F8FAFC', borderRadius: 32, padding: 20, marginBottom: 16, borderWidth: 1, borderColor: '#F1F5F9' },
  cardHeader: { flexDirection: 'row', alignItems: 'center', marginBottom: 14 },
  userAvatarPlaceholder: { width: 42, height: 42, borderRadius: 21, backgroundColor: '#E2E8F0', marginRight: 12, alignItems: 'center', justifyContent: 'center' },
  userNameText: { fontSize: 16, fontWeight: '800', color: '#1E293B' },
  timeStampText: { fontSize: 11, color: '#94A3B8', marginTop: 2 },
  noteContentText: { fontSize: 14, color: '#475569', lineHeight: 22, marginBottom: 14 },
  cardTagRow: { flexDirection: 'row', flexWrap: 'wrap' },
  smallTag: { backgroundColor: 'white', paddingHorizontal: 12, paddingVertical: 6, borderRadius: 14, marginRight: 8, marginBottom: 8, borderWidth: 1, borderColor: '#F1F5F9' },
  smallTagText: { fontSize: 9, fontWeight: '800', color: '#64748B', textTransform: 'uppercase' },
  emptyStateContainer: { paddingVertical: 80, alignItems: 'center', justifyContent: 'center' },
  emptyTitleText: { fontSize: 18, fontWeight: '900', color: '#1E293B', marginTop: 16, fontStyle: 'italic' },
  emptySubText: { fontSize: 13, color: '#94A3B8', textAlign: 'center', marginTop: 8, paddingHorizontal: 50, fontWeight: '600', lineHeight: 20 }
});