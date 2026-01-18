import React, { useCallback, useRef, useState, useEffect, useMemo } from 'react';
import { View, StyleSheet, ScrollView, Image, TouchableOpacity, Dimensions, Animated, Easing, LayoutAnimation, Platform, UIManager, KeyboardAvoidingView } from 'react-native';
import { FlashList } from '@shopify/flash-list';
const MasonryFlashListAny: any = FlashList;
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { ThemedText } from '@/components/ThemedText';
import { Colors } from '@/constants/Colors';

import { useNavigation } from '@react-navigation/native';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { fetchChats, resetChats } from '@/store/slice/chat';


if (Platform.OS === 'android') {
    if (UIManager.setLayoutAnimationEnabledExperimental) {
        UIManager.setLayoutAnimationEnabledExperimental(true);
    }
}



const mockGridData = [
    { id: 'g1', name: 'Ayşe', uri: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400' },
    { id: 'g2', name: 'Mehmet', uri: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400' },
    { id: 'g3', name: 'Fatma', uri: 'https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=400' },
    { id: 'g4', name: 'Ali', uri: 'https://images.unsplash.com/photo-1599566150163-29194dcaad36?w=400' },
    { id: 'g5', name: 'Zeynep', uri: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400' },
    { id: 'g6', name: 'Can', uri: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400' },
    { id: 'g7', name: 'Elif', uri: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400' },
    { id: 'g8', name: 'Burak', uri: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400' },
    { id: 'g9', name: 'Selin', uri: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400' },
    { id: 'g10', name: 'Cem', uri: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400' },
    { id: 'g11', name: 'Deniz', uri: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400' },
    { id: 'g12', name: 'Emre', uri: 'https://images.unsplash.com/photo-1521119989659-a83eee488058?w=400' },
    { id: 'g13', name: 'Gül', uri: 'https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=400' },
    { id: 'g14', name: 'Hakan', uri: 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=400' },
    { id: 'g15', name: 'Seda', uri: 'https://images.unsplash.com/photo-1517365830460-955ce3ccd263?w=400' },
];



export default function Everyone() {
    const navigation = useNavigation();
    const dispatch = useAppDispatch();



    const { chats, loading, error, cursor } = useAppSelector(state => state.chat);

    useEffect(() => {
        loadChats();
    }, [dispatch]);

    const loadChats = () => {
        dispatch(resetChats());
        dispatch(fetchChats({ limit: 20 }));
    }

    const loadMoreChats = () => {
        if (!loading && cursor) {
            dispatch(fetchChats({ limit: 20, cursor }));
        }
    };


    useEffect(() => {
        console.log('Chats updated:', { chats, loading, error });
    }, [chats, loading, error]);




    return (
        <View style={{ flex: 1 }}>

            <MasonryFlashListAny
                style={{ flex: 1 }}
                data={mockGridData}
                numColumns={3}
                masonry
                onEndReached={loadMoreChats}
                onEndReachedThreshold={0.5}
                estimatedItemSize={160}
                keyExtractor={(i: { id: string }) => i.id}
                renderItem={({ item, index }: any) => (
                    <TouchableOpacity
                        style={[styles.gridItem, { height: (index % 3 === 0 ? 220 : 160) }]}
                        activeOpacity={0.8}
                        onPress={() =>
                            (navigation as any).navigate('ChatDetail', {
                                user: {
                                    id: item.id,
                                    name: item.name,
                                    avatar: item.uri,
                                },
                            })
                        }
                    >
                        <Image source={{ uri: item.uri }} style={styles.gridImage} resizeMode="cover" />
                        <View style={styles.gridOverlay}>
                            <ThemedText style={styles.gridName} numberOfLines={1}>{item.name}</ThemedText>
                        </View>
                    </TouchableOpacity>
                )}
                showsVerticalScrollIndicator={false}
                contentContainerStyle={{ paddingHorizontal: 4, paddingTop: 4 }}
            />
        </View>
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
    },
    iconBtn: {
        marginLeft: 12,
        padding: 10,
        borderRadius: 20,
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