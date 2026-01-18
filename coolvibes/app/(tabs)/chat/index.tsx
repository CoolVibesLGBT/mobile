import React, { useCallback, useRef, useState, useEffect } from 'react';
import { View, StyleSheet, ScrollView, Image, TouchableOpacity, Dimensions, Animated, Easing } from 'react-native';
import { FlashList } from '@shopify/flash-list';
const FlashListAny: any = FlashList;
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { ThemedText } from '@/components/ThemedText';
import { ThemedView } from '@/components/ThemedView';
import { Colors } from '@/constants/Colors';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { fetchChats, resetChats } from '@/store/slice/chat';
import { Constants } from '@/constants/Constants';
import { IconSymbol } from '@/components/ui/icon-symbol';
import { useRouter } from 'expo-router';

const { width } = Dimensions.get('window');

const mockStories = [
    { id: 'likes', label: 'Beğeniler', badge: 24, uri: 'https://picsum.photos/seed/likes/200' },
    { id: '1', label: 'Metin', uri: 'https://picsum.photos/seed/1/200' },
    { id: '2', label: 'Chk', uri: 'https://picsum.photos/seed/2/200' },
    { id: '3', label: 'Ram', uri: 'https://picsum.photos/seed/3/200' },
    { id: '4', label: 'Ayhan', uri: 'https://picsum.photos/seed/4/200' },
];

// Reusable stories list (compact = sticky variant)
const Stories = ({ compact = false, showTitle }: { compact?: boolean; showTitle?: boolean }) => {
    const shouldShowTitle = typeof showTitle === 'boolean' ? showTitle : !compact;
    return (
        <View style={styles.storiesWrapper}>
            {shouldShowTitle && (
                <ThemedText style={styles.sectionTitle} type="defaultSemiBold">
                    Beğeniler ve eşleşmeler
                </ThemedText>
            )}
            <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.stories}>
                {mockStories.map((s) => (
                    <TouchableOpacity key={s.id} style={styles.storyItem} activeOpacity={0.8} onPress={() => console.log(compact ? 'sticky pressed' : 'story pressed', s.id)}>
                        <View style={[styles.avatarWrapper, s.id === 'likes' && styles.likesAvatar]}>
                            <Image source={{ uri: s.uri }} style={styles.avatar} />
                            {s.id === 'likes' ? (
                                <View style={[styles.likesBadge, compact && styles.likesBadgeSticky]}>
                                    <ThemedText style={{ color: 'white', fontWeight: '700', fontSize: 12 }}>{s.badge}</ThemedText>
                                </View>
                            ) : (
                                <View style={styles.redDot} />
                            )}
                        </View>
                        {!compact && <ThemedText style={styles.storyLabel}>{s.label}</ThemedText>}
                    </TouchableOpacity>
                ))}
            </ScrollView>
        </View>
    );
};

const mockMessages = [
    { id: 'm1', name: 'Ayhan', text: 'İyiyim teşekkür ederim sağolun siz nasılsınız', uri: 'https://picsum.photos/seed/a/200' },
    { id: 'm2', name: 'EFE', text: 'İyimmm teşekkür ederim siz nasılsınız', uri: 'https://picsum.photos/seed/b/200' },
    { id: 'm3', name: 'Mert', text: 'Selam, nasılsın?', uri: 'https://picsum.photos/seed/c/200' },
    { id: 'm4', name: 'Mert', text: 'Selam, nasılsın?', uri: 'https://picsum.photos/seed/c/200' },
    { id: 'm5', name: 'Mert', text: 'Selam, nasılsın?', uri: 'https://picsum.photos/seed/c/200' },
    { id: 'm6', name: 'Mert', text: 'Selam, nasılsın?', uri: 'https://picsum.photos/seed/c/200' },

];

export default function Chat() {
    const insets = useSafeAreaInsets();
    const headerHeightRef = useRef<number | null>(56);
    const dispatch = useAppDispatch();
    const router = useRouter();

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
        <ThemedView style={styles.container}>
            <SafeAreaView style={{ flex: 1 }}>
                <View style={styles.headerRow} onLayout={(e) => (headerHeightRef.current = e.nativeEvent.layout.height)}>
                    <ThemedText type="title">Sohbet</ThemedText>
                    <View style={styles.headerIcons}>
                        <TouchableOpacity onPress={() => {
                            loadChats()
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

                <View style={{ paddingHorizontal: 16, marginTop: 8 }}>
                    <Stories compact={false} showTitle={true} />
                </View>

                <FlashListAny
                    style={{ flex: 1 }}
                    data={mockMessages}
                    onEndReached={loadMoreChats}
                    onEndReachedThreshold={0.5}
                    estimatedItemSize={86}
                    keyExtractor={(i: { id: string }) => i.id}
                    renderItem={({ item }: { item: { id: string; name: string; text: string; uri: string } }) => (
                        <TouchableOpacity
                            style={styles.messageRow}
                            activeOpacity={0.8}
                            onPress={() =>
                                router.push({
                                    pathname: '/chat/[chatId]',
                                    params: { chatId: item.id },
                                })}>
                            <Image source={{ uri: item.uri }} style={styles.messageAvatar} />
                            <View style={{ flex: 1, marginLeft: 12 }}>
                                <ThemedText type="defaultSemiBold">{item.name}</ThemedText>
                                <ThemedText style={{ marginTop: 6, color: '#6b6b6b' }}>{item.text}</ThemedText>
                            </View>
                            <View style={{ padding: 8 }}>
                                <IconSymbol name="chevron.right" size={22} color={Colors.light.icon} />
                            </View>
                        </TouchableOpacity>
                    )}
                    showsVerticalScrollIndicator={false}
                    ListHeaderComponent={() => (
                        <>
                            <View style={styles.sectionHeaderRow}>
                                <ThemedText style={styles.sectionTitle} type="defaultSemiBold">Mesajlar</ThemedText>

                            </View>




                        </>
                    )}
                    contentContainerStyle={{ paddingHorizontal: 16, paddingTop: 8, paddingBottom: 120 }}
                />

            </SafeAreaView>
        </ThemedView >
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
});