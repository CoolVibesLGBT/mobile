import React, { useCallback, useRef, useState, useEffect, useMemo } from 'react';
import { View, StyleSheet, ScrollView, Image, TouchableOpacity, Dimensions, Animated, Easing, LayoutAnimation, Platform, UIManager, KeyboardAvoidingView } from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { ThemedText } from '@/components/ThemedText';
import { ThemedView } from '@/components/ThemedView';
import { Colors } from '@/constants/Colors';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { useNavigation } from '@react-navigation/native';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { fetchChats, resetChats } from '@/store/slice/chat';
import { Directions, Gesture, GestureDetector } from 'react-native-gesture-handler';
import { runOnJS } from 'react-native-reanimated';
import { BottomSheetModal, BottomSheetModalProvider, BottomSheetView } from '@gorhom/bottom-sheet';
import { CheckIn } from '@/components/CheckInBar';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';
import NearBy from '@/components/Screens/Discover/DiscoverTabs/NearBy';
import Everyone from '@/components/Screens/Discover/DiscoverTabs/Everyone';
import systemReducer, { fetchInitialSync } from '@/store/slice/system';
import RightNow from '@/components/Screens/Discover/DiscoverTabs/RightNow';
import Today from '@/components/Screens/Discover/DiscoverTabs/Today';
import DiscoverTab from '@/components/Screens/Discover/DiscoverTabs/Discover';
import { Constants } from '@/constants/Constants';

const { width } = Dimensions.get('window');

if (Platform.OS === 'android') {
  if (UIManager.setLayoutAnimationEnabledExperimental) {
    UIManager.setLayoutAnimationEnabledExperimental(true);
  }
}

export default function Discover() {
  const insets = useSafeAreaInsets();
  const headerHeightRef = useRef<number | null>(56);
  const navigation = useNavigation();

    const dispatch = useAppDispatch();
  const { loading, error, data } = useAppSelector(state => state.system);



  const [activeTab, setActiveTab] = useState<'today' | 'now' | 'everyone' | 'here' | 'discover'>('now');
  const bottomSheetModalRef = useRef<BottomSheetModal>(null);

  // callbacks
  const handlePresentModalPress = useCallback(() => {
    bottomSheetModalRef.current?.present();
  }, []);
  const handleSheetChanges = useCallback((index: number) => {
    console.log('handleSheetChanges', index);
  }, []);

  const onSwipe = useCallback((direction: 'left' | 'right') => {
    let nextTab = activeTab;
    if (direction === 'left') {
      if (activeTab === 'now') nextTab = 'everyone';
      else if (activeTab === 'everyone') nextTab = 'here';
    } else {
      if (activeTab === 'here') nextTab = 'everyone';
      else if (activeTab === 'everyone') nextTab = 'now';
    }

    if (nextTab !== activeTab) {
      LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
      setActiveTab(nextTab);
    }
  }, [activeTab]);

  const gestures = useMemo(() => {
    const flingLeft = Gesture.Fling().direction(Directions.LEFT).onEnd(() => {
      runOnJS(onSwipe)('left');
    });
    const flingRight = Gesture.Fling().direction(Directions.RIGHT).onEnd(() => {
      runOnJS(onSwipe)('right');
    });
    return Gesture.Simultaneous(flingLeft, flingRight);
  }, [onSwipe]);




 

  useEffect(() => {
    console.log('Chats updated:',data?.checkin_tag_types);
  }, [loading, error]);



  const TABS = [
    { key: 'today', label: 'Bugün' },
    { key: 'now', label: 'Şimdi' },
    { key: 'everyone', label: 'Herkes' },
    { key: 'here', label: 'Yakınımda' },
    { key: 'discover', label: 'Keşfet' },
  ];
  const scrollRef = useRef<ScrollView>(null);

  const insetsConfig = useSafeAreaInsets()
  console.log("InsetConfigs",insetsConfig)
  return (
    <GestureDetector gesture={gestures}>
      <KeyboardAvoidingView style={styles.container} behavior={Platform.OS === "ios" ? "padding" : undefined}>

        <ThemedView style={[styles.container]}>
          <SafeAreaView edges={["top"]} style={{ flex: 1 }}>



            <View style={styles.headerRow} onLayout={(e) => (headerHeightRef.current = e.nativeEvent.layout.height)}>
              <ThemedText type="title">Keşfet</ThemedText>
              <View style={styles.headerIcons}>
                <TouchableOpacity onPress={() => {
                  //loadChats()
                }} style={styles.iconBtn} hitSlop={{ top: 8, left: 8, right: 8, bottom: 8 }}>
                  <MaterialIcons name="refresh" size={Constants.headerIconSize} color="#fff" />
                </TouchableOpacity>
                <TouchableOpacity style={styles.iconBtn} hitSlop={{ top: 8, left: 8, right: 8, bottom: 8 }}>
                  <View>
                    <MaterialIcons name="notifications-none" size={Constants.headerIconSize} color="#fff" />
                    <View style={styles.redDotSmall} />
                  </View>
                </TouchableOpacity>
                <TouchableOpacity style={styles.iconBtn} hitSlop={{ top: 8, left: 8, right: 8, bottom: 8 }}>
                  <MaterialIcons name="search" size={Constants.headerIconSize} color="#fff" />
                </TouchableOpacity>
              </View>
            </View>

            <View style={{ height: 40 }}>
              <ScrollView
                ref={scrollRef}
                horizontal
                showsHorizontalScrollIndicator={false}
                contentContainerStyle={styles.tabsContainer}
              >
                {TABS.map((tab, index) => {
                  const active = activeTab === tab.key;

                  return (
                    <TouchableOpacity
                      key={tab.key}
                      style={styles.tabItem}
                      activeOpacity={0.7}
                      onPress={() => {
                        LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
                        setActiveTab(tab.key);
                      }}
                    >
                      <ThemedText style={[styles.tabText, active && styles.tabTextActive]}>
                        {tab.label}
                      </ThemedText>

                      {/* iOS-style underline */}
                      {active && <View style={styles.activeIndicator} />}
                    </TouchableOpacity>
                  );
                })}
              </ScrollView>
            </View>
            <View style={{ flex: 1 }}>


              {activeTab === 'today' ? (
               <Today />
              ) : activeTab === 'now' ? (
               <RightNow />
              ) : activeTab === 'everyone' ? (
                <Everyone />
              ) : activeTab === 'here' ? (
                <NearBy />
              ) : activeTab === 'discover' ? (
                <DiscoverTab />
              ): (
                <Everyone />
              )}
            </View>


            <TouchableOpacity
              style={styles.fab}
              activeOpacity={0.8}
              onPress={() => {
                handlePresentModalPress()
                //bottomSheetModalRef.current?.present();
              }}
            >
              <MaterialCommunityIcons name="foot-print" size={28} color="#fff" />
              <ThemedText style={styles.fabText}>Check-in</ThemedText>
            </TouchableOpacity>

            <BottomSheetModalProvider>

              <BottomSheetModal
                enableDynamicSizing={true}
                ref={bottomSheetModalRef}
                onChange={handleSheetChanges}
              >
                <BottomSheetView style={{ flex: 1 }}>
                  <CheckIn />

                </BottomSheetView>
              </BottomSheetModal>
            </BottomSheetModalProvider>
          </SafeAreaView>

        </ThemedView>
      </KeyboardAvoidingView>
    </GestureDetector>

  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    marginTop: 8,
  },
  headerIcons: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  iconBtn: {
        padding: 10,
        borderRadius: 100,
        flexDirection: "row",
        alignItems: "center",
        backgroundColor: "black",
        shadowColor: "#000",
        shadowOpacity: 0.05,
        shadowRadius: 2,
        shadowOffset: { width: 0, height: 1 },
  },
  redDotSmall: {
    position: 'absolute',
    right: -2,
    top: -2,
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#ff3b30',
    borderWidth: 1,
    borderColor: 'white',
  },
  scroll: {
    paddingHorizontal: 16,
    marginTop: 8,
  },
  sectionTitle: {
    fontSize: 18,
    marginBottom: 8,
  },
  stickySection: {
    backgroundColor: Colors.light.background,
    paddingVertical: 8,
    paddingHorizontal: 0,
    zIndex: 10,
    // allow badges to render outside the avatar bounds
    overflow: 'visible',
  },


  contentContainer: {
    flex: 1,
    alignItems: 'center',
  },
  stories: {
    marginBottom: 16,
    overflow: 'visible',
  },

  storyItem: {
    width: 72,
    alignItems: 'center',
    marginRight: 12,
  },
  avatarWrapper: {
    width: 64,
    height: 96,
    borderRadius: 12,
    overflow: 'visible',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: 'transparent',
  },
  likesAvatar: {
    borderColor: '#ff3b30',
    borderWidth: 3,
    borderRadius: 12,
  },
  avatar: {
    width: 64,
    height: 96,
    borderRadius: 12,
  },
  likesBadge: {
    position: 'absolute',
    // slightly less negative offsets to keep the badge fully visible
    right: -6,
    bottom: -10,
    backgroundColor: '#ff3b30',
    borderRadius: 18,
    width: 36,
    height: 36,
    alignItems: 'center',
    justifyContent: 'center',
    elevation: 2,
    shadowColor: '#000',
    shadowOpacity: 0.14,
    shadowRadius: 4,
    shadowOffset: { width: 0, height: 2 },
  },
  likesBadgeSticky: {
    // slightly smaller offset so the badge is fully visible inside the sticky bar
    right: -4,
    bottom: -4,
    width: 36,
    height: 36,
    borderRadius: 18,
    transform: [{ scale: 0.98 }],
    elevation: 4,
    shadowOpacity: 0.16,
  },
  redDot: {
    position: 'absolute',
    right: 4,
    top: 4,
    width: 10,
    height: 10,
    borderRadius: 5,
    backgroundColor: '#ff3b30',
    borderWidth: 1,
    borderColor: 'white',
  },
  storyLabel: {
    marginTop: 6,
    fontSize: 12,
  },
  sectionHeaderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: 8,
  },
  sortRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  matchCard: {
    backgroundColor: '#f4f4f6',
    borderRadius: 18,
    padding: 14,
    marginTop: 12,
    marginBottom: 12,
  },
  matchRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  matchAvatar: {
    width: 58,
    height: 58,
    borderRadius: 10,
  },
  matchButtonsRow: {
    flexDirection: 'row',
    marginTop: 12,
    justifyContent: 'space-between',
  },
  outlineButton: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 20,
    borderWidth: 2,
    borderColor: '#000',
    alignItems: 'center',
    marginRight: 8,
    backgroundColor: 'white',
  },
  filledButton: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 20,
    alignItems: 'center',
    backgroundColor: '#111',
  },
  infoRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 14,
    borderRadius: 12,
    backgroundColor: 'white',
    paddingHorizontal: 12,
    marginBottom: 12,
  },
  compositeCircle: {
    width: 58,
    height: 58,
    borderRadius: 29,
    position: 'relative',
  },
  smallImg: {
    width: 28,
    height: 28,
    borderRadius: 6,
    position: 'absolute',
    left: 0,
    top: 0,
  },
  smallImg2: {
    left: 26,
    top: 0,
  },
  smallImg3: {
    left: 0,
    top: 26,
  },
  smallImg4: {
    left: 26,
    top: 26,
  },
  messageRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 14,
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
  },
  messageAvatar: {
    width: 56,
    height: 56,
    borderRadius: 10,
  },
  storiesAbsolute: {
    position: 'absolute',
    zIndex: 100,
  },
  storiesWrapper: {
    width: '100%',
    paddingBottom: 8,
    paddingTop: 4,
  },


  tabsContainer: {
    height: 40,
    flex: 1,
    flexDirection: "row",
    paddingHorizontal: 16,
    gap: 20,
  },
  tabItem: {
    alignItems: 'center',
    paddingVertical: 8,
  },
  tabText: {
    fontSize: 16,
    color: '#8E8E93',
    fontWeight: '500',
  },
  tabTextActive: {
    color: '#000',
    fontWeight: '600',
  },
  activeIndicator: {
    marginTop: 3,
    height: 4,
    width: '100%',
    borderRadius: 1,
    backgroundColor: '#000',
  },
  fab: {
    position: 'absolute',
    bottom: 24,
    right: 16,
    backgroundColor: '#000',
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 20,
    borderRadius: 28,
    elevation: 5,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
  },
  fabText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
    marginLeft: 8,
  },
  gridItem: {
    flex: 1,
    margin: 4,
    borderRadius: 12,
    overflow: 'hidden',
    backgroundColor: '#f0f0f0',
  },
  gridImage: {
    width: '100%',
    height: '100%',
  },
  gridOverlay: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    padding: 6,
    backgroundColor: 'rgba(0,0,0,0.3)',
  },
  gridName: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
    textAlign: 'center',
  },
  markerContainer: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  markerAvatar: {
    width: 50,
    height: 50,
    borderRadius: 100,
  },
  markerOuterRing: {
    padding: 8,
    borderRadius: 100,
  },
  markerInnerRing: {
    borderRadius: 100,
    borderWidth: 3,
  },
  markerBadge: {
    position: 'absolute',
    bottom: 0,
    right: 0,
    width: 14,
    height: 14,
    borderRadius: 7,
    backgroundColor: '#34C759',
    borderWidth: 2,
    borderColor: '#fff',
  },
  mapControls: {
    position: 'absolute',
    top: 16,
    right: 16,
    alignItems: 'center',
  },
  mapControlBtn: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: '#000',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 10,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
  },
});