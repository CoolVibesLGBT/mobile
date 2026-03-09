
import React, { useRef, useMemo, useState, useCallback } from 'react';
import { View, Text, StyleSheet, FlatList, TouchableOpacity, Dimensions, Platform, KeyboardAvoidingView } from 'react-native';
import { useTheme } from '@react-navigation/native';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { CheckInRadar } from '@/components/CheckInBar';
import PostCard from '@/components/PostCard';
import ChatInput from '@/components/ChatInput';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { useAppSelector } from '@/store/hooks';
import Animated, { FadeIn, FadeOut } from 'react-native-reanimated';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

const MOCK_CHECKINS = [
    {
        id: 1,
        user: { name: 'Alex Thompson', username: 'alex_t', avatar: 'https://i.pravatar.cc/150?u=alex' },
        image: 'https://picsum.photos/800/800?random=11',
        caption: 'Checking in at the Rainbow Hub! 🌈 #inclusive #vibes',
        likes: 42,
        comments: 5,
        time: 'Just now',
    },
    {
        id: 2,
        user: { name: 'Jordan Blue', username: 'jordan_b', avatar: 'https://i.pravatar.cc/150?u=jordan' },
        image: 'https://picsum.photos/800/800?random=12',
        caption: 'Great atmosphere here. Feeling productive. ☕️',
        likes: 128,
        comments: 12,
        time: '20 mins ago',
    },
    {
        id: 3,
        user: { name: 'Taylor Swift', username: 'taylor_s', avatar: 'https://i.pravatar.cc/150?u=taylor' },
        image: 'https://picsum.photos/800/800?random=13',
        caption: 'Love the new monochrome theme! So sleek. ⚫️⚪️',
        likes: 850,
        comments: 45,
        time: '1 hour ago',
    },
];

type ScreenMode = 'nearby' | 'create';

export default function CheckInScreen() {
    const { colors, dark } = useTheme();
    const insets = useSafeAreaInsets();
    const router = useRouter();
    const authUser = useAppSelector(state => state.auth.user);
    const [mode, setMode] = useState<ScreenMode>('create');
    const [selectedTags, setSelectedTags] = useState<string[]>([]);
    
    const handleSelectTag = (tag: string) => {
        setSelectedTags(prev => 
            prev.includes(tag) ? prev.filter(t => t !== tag) : [...prev, tag]
        );
    };

    const handleClearTags = () => {
        setSelectedTags([]);
    };

    const handleSendMessage = (text: string, media: any[]) => {
        console.log("Check-in Sent:", { text, media, selectedTags });
        // After sending, transition back or show success
        router.back();
    };

    const borderColor = dark ? '#222' : '#F0F0F0';
    const activeBg = dark ? '#FFF' : '#000';
    const activeText = dark ? '#000' : '#FFF';

    return (
        <View style={[styles.container, { backgroundColor: colors.background, paddingTop: 60 + insets.top }]}>
            {/* Internal Header - REMOVED to favor GlobalHeader */}
            {/* 
            <View style={[styles.header, { paddingTop: insets.top + 10, borderBottomColor: borderColor }]}>
                <TouchableOpacity onPress={() => router.back()} style={styles.iconBtn}>
                    <MaterialCommunityIcons name="close" size={24} color={colors.text} />
                </TouchableOpacity>

                <View style={[styles.modeSwitcher, { backgroundColor: dark ? '#1A1A1A' : '#F5F5F5' }]}>
                    <TouchableOpacity 
                        onPress={() => setMode('create')}
                        style={[styles.modeBtn, mode === 'create' && { backgroundColor: activeBg }]}
                    >
                        <Text style={[styles.modeText, { color: mode === 'create' ? activeText : colors.text, opacity: mode === 'create' ? 1 : 0.5 }]}>
                            MY VIBE
                        </Text>
                    </TouchableOpacity>
                    <TouchableOpacity 
                        onPress={() => setMode('nearby')}
                        style={[styles.modeBtn, mode === 'nearby' && { backgroundColor: activeBg }]}
                    >
                        <Text style={[styles.modeText, { color: mode === 'nearby' ? activeText : colors.text, opacity: mode === 'nearby' ? 1 : 0.5 }]}>
                            NEARBY
                        </Text>
                    </TouchableOpacity>
                </View>

                <TouchableOpacity style={styles.iconBtn}>
                    <MaterialCommunityIcons name="history" size={24} color={colors.text} />
                </TouchableOpacity>
            </View>
            */}

            {/* Screen Content */}
            <View style={styles.titleArea}>
                <Text style={[styles.screenTitle, { color: colors.text }]}>CHECK-IN</Text>
                <Text style={[styles.screenSubtitle, { color: colors.text }]}>What's your vibe today?</Text>
            </View>

            {/* Sub-Header: Mode Switcher */}
            <View style={styles.subHeader}>
                <View style={[styles.modeSwitcher, { backgroundColor: dark ? '#111' : '#F5F5F5', borderColor: borderColor, borderWidth: 1 }]}>
                    <TouchableOpacity 
                        onPress={() => setMode('create')}
                        style={[styles.modeBtn, mode === 'create' && { backgroundColor: activeBg }]}
                        activeOpacity={0.8}
                    >
                        <Text style={[styles.modeText, { color: mode === 'create' ? activeText : colors.text, opacity: mode === 'create' ? 1 : 0.4 }]}>
                            MY VIBE
                        </Text>
                    </TouchableOpacity>
                    <TouchableOpacity 
                        onPress={() => setMode('nearby')}
                        style={[styles.modeBtn, mode === 'nearby' && { backgroundColor: activeBg }]}
                        activeOpacity={0.8}
                    >
                        <Text style={[styles.modeText, { color: mode === 'nearby' ? activeText : colors.text, opacity: mode === 'nearby' ? 1 : 0.4 }]}>
                            NEARBY
                        </Text>
                    </TouchableOpacity>
                </View>
            </View>

            {/* Content Area */}
            <View style={styles.content}>
                {mode === 'nearby' ? (
                    <Animated.View 
                        entering={FadeIn.duration(200)} 
                        exiting={FadeOut.duration(200)}
                        style={{ flex: 1 }}
                    >
                        <FlatList
                            data={MOCK_CHECKINS}
                            keyExtractor={(item) => item.id.toString()}
                            renderItem={({ item }) => <PostCard {...item} />}
                            contentContainerStyle={[styles.listContent, { paddingBottom: insets.bottom + 20 }]}
                            showsVerticalScrollIndicator={false}
                        />
                    </Animated.View>
                ) : (
                    <Animated.View 
                        entering={FadeIn.duration(200)} 
                        exiting={FadeOut.duration(200)}
                        style={{ flex: 1 }}
                    >
                        <View style={{ flex: 1 }}>
                            <CheckInRadar 
                                selectedTags={selectedTags} 
                                onSelectTag={handleSelectTag}
                                onClearTags={handleClearTags}
                            />
                        </View>
                        
                        {/* Chat Input Pinned for Radar Mode */}
                        <KeyboardAvoidingView 
                            behavior={Platform.OS === 'ios' ? 'padding' : undefined}
                            keyboardVerticalOffset={Platform.OS === 'ios' ? 90 : 0}
                            style={[styles.inputWrapper, { paddingBottom: insets.bottom + 10 }]}
                        >
                            <ChatInput
                                currentUser={authUser}
                                onSendMessage={handleSendMessage}
                                replyingTo={null}
                                onCancelReply={() => null}
                                editingMessage={null}
                                onCancelEdit={() => null}
                            />
                        </KeyboardAvoidingView>
                    </Animated.View>
                )}
            </View>
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
    },
    titleArea: {
        paddingHorizontal: 20,
        paddingTop: 10,
        paddingBottom: 5,
        alignItems: 'center',
    },
    screenTitle: {
        fontSize: 32,
        fontFamily: 'Outfit-Black',
        letterSpacing: -1,
        textTransform: 'uppercase',
    },
    screenSubtitle: {
        fontSize: 14,
        fontFamily: 'Inter-SemiBold',
        opacity: 0.5,
        marginTop: 2,
    },
    subHeader: {
        alignItems: 'center',
        paddingVertical: 15,
        backgroundColor: 'transparent',
    },
    header: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        paddingHorizontal: 16,
        paddingBottom: 15,
        borderBottomWidth: 1,
    },
    iconBtn: {
        width: 44,
        height: 44,
        alignItems: 'center',
        justifyContent: 'center',
    },
    modeSwitcher: {
        flexDirection: 'row',
        borderRadius: 22,
        padding: 4,
        width: 210,
    },
    modeBtn: {
        flex: 1,
        height: 32,
        borderRadius: 18,
        alignItems: 'center',
        justifyContent: 'center',
    },
    modeText: {
        fontSize: 10,
        fontFamily: 'Inter-Bold',
        letterSpacing: 1,
    },
    content: {
        flex: 1,
    },
    listContent: {
        paddingTop: 8,
    },
    inputWrapper: {
        width: '100%',
        backgroundColor: 'transparent',
    },
});
