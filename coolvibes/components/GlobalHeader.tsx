
import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Platform, ViewStyle, TextStyle } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '@react-navigation/native';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useRouter, useSegments } from 'expo-router';
import { BlurView } from 'expo-blur';
import { Image } from 'expo-image';

export default function GlobalHeader() {
    const insets = useSafeAreaInsets();
    const { colors, dark } = useTheme();
    const router = useRouter();
    const segments = useSegments();

    const isAuth = (segments as any[])[0] === '(auth)';
    const isChatDetail = (segments as any[]).includes('ChatDetail');
    const isCheckIn = (segments as any[]).includes('CheckIn');
    const isMatch = (segments as any[]).includes('Match') || (segments as any[]).includes('MatchScreen');

    // Hide GlobalHeader on Match (Radar) and Auth for specific UX requirements
    if (isAuth || isMatch) return null;
    
    // Root screens show Logo + Settings + Profile
    const rootSubSegments = ['index', 'chat', 'Profile', 'Discover', 'nearby'];
    const segs = segments as string[];
    const isRoot = !isChatDetail && !isCheckIn && (
        segs.length === 0 || 
        (segs.length === 1 && segs[0] === '(tabs)') ||
        (segs.length === 2 && segs[0] === '(tabs)' && rootSubSegments.includes(segs[1]))
    );


    // Mocked data for ChatDetail (In real app, this would come from a Global State/Provider)
    const chatUser = {
        name: "RIGHT6652",
        status: "online",
        avatar: "https://i.pravatar.cc/150?u=right6652"
    };

    const containerStyle: ViewStyle = { 
        height: 60 + insets.top, 
        paddingTop: insets.top,
        width: '100%',
        position: 'absolute',
        top: 0,
        zIndex: 1000,
        backgroundColor: 'transparent',
    };

    const contentStyle: ViewStyle = {
        flex: 1,
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        paddingHorizontal: 16,
        borderBottomWidth: 0.5,
        borderBottomColor: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.08)',
    };

    const brandText: TextStyle = {
        fontSize: 18,
        fontFamily: 'Outfit-Black',
        letterSpacing: 2,
        color: colors.text,
        textTransform: 'uppercase'
    };

    const renderCenter = () => {
        if (isChatDetail) {
            return (
                <View style={styles.chatHeaderCenter}>
                    <Text style={[styles.chatName, { color: colors.text }]}>{chatUser.name}</Text>
                    <View style={styles.statusRow}>
                        <View style={[styles.statusDot, { backgroundColor: colors.text + '80' }]} />
                        <Text style={[styles.chatStatus, { color: colors.text + '80' }]}>{chatUser.status}</Text>
                    </View>
                </View>
            );
        }
        return (
            <View style={styles.brandContainer}>
                <Text style={brandText}>COOLVIBES</Text>
            </View>
        );
    };

    const renderRight = () => {
        if (isChatDetail) {
            return (
                <TouchableOpacity style={styles.avatarBtn} activeOpacity={0.7}>
                    <Image source={{ uri: chatUser.avatar }} style={styles.headerAvatar} />
                </TouchableOpacity>
            );
        }
        return (
            <TouchableOpacity 
                onPress={() => router.push('/(tabs)/Profile')} 
                style={styles.iconBtn}
                activeOpacity={0.7}
            >
                <MaterialCommunityIcons name="account-circle-outline" size={28} color={colors.text} />
            </TouchableOpacity>
        );
    };
    const borderColor = dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.05)';

    return (
        <View style={[containerStyle, (!isRoot && !isChatDetail && !isCheckIn) && { borderBottomWidth: 1, borderBottomColor: borderColor }]}>
            <BlurView
                intensity={dark ? 40 : 100}
                style={StyleSheet.absoluteFill}
                tint={dark ? 'dark' : 'light'}
            />
            <View style={contentStyle}>
                {/* Left: Action Icon */}
                <TouchableOpacity 
                    onPress={() => {
                        if (isCheckIn || isChatDetail) router.back();
                        else if (isRoot) router.push('/search');
                        else router.back();
                    }} 
                    style={styles.iconBtn}
                    activeOpacity={0.7}
                >
                    <MaterialCommunityIcons 
                        name={isCheckIn ? "close" : (isRoot ? "tune-vertical" : "chevron-left")} 
                        size={isCheckIn ? 28 : (isRoot ? 24 : 32)} 
                        color={colors.text} 
                    />
                </TouchableOpacity>

                {/* Center */}
                {renderCenter()}

                {/* Right */}
                {renderRight()}
            </View>
        </View>
    );
}

const styles = StyleSheet.create({
    brandContainer: {
        flex: 1,
        alignItems: 'center',
    },
    chatHeaderCenter: {
        flex: 1,
        alignItems: 'center',
        justifyContent: 'center',
    },
    chatName: {
        fontSize: 15,
        fontFamily: 'Outfit-Black',
        textTransform: 'uppercase',
        letterSpacing: 0.5,
    },
    statusRow: {
        flexDirection: 'row',
        alignItems: 'center',
        marginTop: 1,
        gap: 4,
    },
    statusDot: {
        width: 6,
        height: 6,
        borderRadius: 3,
        backgroundColor: '#666', // Monochrome
    },
    chatStatus: {
        fontSize: 10,
        fontFamily: 'Inter-SemiBold',
    },
    avatarBtn: {
        width: 44,
        height: 44,
        alignItems: 'center',
        justifyContent: 'center',
    },
    headerAvatar: {
        width: 34,
        height: 34,
        borderRadius: 17,
        borderWidth: 1,
        borderColor: 'rgba(255,255,255,0.1)',
    },
    iconBtn: {
        width: 44,
        height: 44,
        alignItems: 'center',
        justifyContent: 'center',
    },
});
