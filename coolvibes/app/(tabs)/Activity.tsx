import React, { useState, memo, useCallback } from 'react';
import {
    View,
    Text,
    StyleSheet,
    TouchableOpacity,
    Dimensions,
    Platform,
    Image,
    StatusBar,
    ScrollView,
} from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { FlashList } from '@shopify/flash-list';
const FlashListAny: any = FlashList;
import Animated, { 
    FadeIn, 
    FadeOut, 
    useAnimatedStyle, 
    withSpring,
    useSharedValue,
    interpolate,
} from 'react-native-reanimated';
import { 
    Bell, 
    Users, 
    Eye, 
    Heart, 
    Sparkles, 
    UserPlus, 
    ChevronRight,
    MessageCircle,
    Star,
    History
} from 'lucide-react-native';
import { useRouter } from 'expo-router';
import { useAppSelector } from '@/store/hooks';

const { width } = Dimensions.get('window');

// --- Mock Data ---

const NOTIFICATIONS = [
    { id: '1', type: 'like', user: 'Sophia', avatar: 'https://i.pravatar.cc/150?u=Sophia', content: 'liked your photo', time: '2m' },
    { id: '2', type: 'match', user: 'Lucas', avatar: 'https://i.pravatar.cc/150?u=Lucas', content: 'You have a new match!', time: '15m' },
    { id: '3', type: 'system', user: 'CoolVibes', avatar: '', content: 'Welcome to the community!', time: '1h' },
    { id: '4', type: 'sparkle', user: 'Emma', avatar: 'https://i.pravatar.cc/150?u=Emma', content: 'sent you a Super Like!', time: '3h' },
    { id: '5', type: 'comment', user: 'Aiden', avatar: 'https://i.pravatar.cc/150?u=Aiden', content: 'commented on your post', time: '5h' },
];

const SOCIAL = [
    { id: 's1', user: 'Isabella', avatar: 'https://i.pravatar.cc/150?u=Isabella', bio: 'Living life to the fullest ✨', isFollowing: true, status: 'follower' },
    { id: 's2', user: 'Oliver', avatar: 'https://i.pravatar.cc/150?u=Oliver', bio: 'Tech enthusiast & Coffee lover', isFollowing: false, status: 'following' },
    { id: 's3', user: 'Mia', avatar: 'https://i.pravatar.cc/150?u=Mia', bio: 'Adventure seeker | Traveler', isFollowing: true, status: 'both' },
    { id: 's4', user: 'James', avatar: 'https://i.pravatar.cc/150?u=James', bio: 'Musician & Dreamer', isFollowing: true, status: 'follower' },
];

const VISITORS = [
    { id: 'v1', user: 'Charlotte', avatar: 'https://i.pravatar.cc/150?u=Charlotte', time: '10m ago', type: 'viewer' },
    { id: 'v3', user: 'Amelia', avatar: 'https://i.pravatar.cc/150?u=Amelia', time: '3h ago', type: 'viewer' },
    { id: 'v5', user: 'Noah', avatar: 'https://i.pravatar.cc/150?u=Noah', time: '5h ago', type: 'viewer' },
];

const VISITED = [
    { id: 'v2', user: 'Benjamin', avatar: 'https://i.pravatar.cc/150?u=Benjamin', time: '1h ago', type: 'viewed' },
    { id: 'v4', user: 'Henry', avatar: 'https://i.pravatar.cc/150?u=Henry', time: 'Yesterday', type: 'viewed' },
    { id: 'v6', user: 'Liam', avatar: 'https://i.pravatar.cc/150?u=Liam', time: '2 days ago', type: 'viewed' },
];

// --- Components ---

const NotificationItem = memo(({ item, dark, blurPhotos }: any) => {
    const getIcon = () => {
        switch (item.type) {
            case 'like': return <Heart size={14} color="#FF3B30" fill="#FF3B30" />;
            case 'match': return <Sparkles size={14} color="#FFD700" fill="#FFD700" />;
            case 'sparkle': return <Star size={14} color="#AF52DE" fill="#AF52DE" />;
            case 'comment': return <MessageCircle size={14} color="#007AFF" />;
            default: return <Bell size={14} color="#8E8E93" />;
        }
    };

    return (
        <TouchableOpacity style={[styles.itemContainer, { borderBottomColor: dark ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.05)' }]} activeOpacity={0.7}>
            <View style={styles.itemLeft}>
                <View style={styles.avatarContainer}>
                    {item.avatar ? (
                        <Image source={{ uri: item.avatar }} style={styles.itemAvatar} blurRadius={blurPhotos ? 12 : 0} />
                    ) : (
                        <View style={[styles.itemAvatar, { backgroundColor: dark ? '#1A1A1A' : '#F5F5F5', alignItems: 'center', justifyContent: 'center' }]}>
                             <Bell size={24} color={dark ? '#333' : '#CCC'} />
                        </View>
                    )}
                    <View style={[styles.iconBadge, { backgroundColor: dark ? '#000' : '#FFF', borderColor: dark ? '#000' : '#FFF' }]}>{getIcon()}</View>
                </View>
                <View style={styles.itemInfo}>
                    <Text style={[styles.itemTitle, { color: dark ? '#E0E0E0' : '#333' }]}>
                        <Text style={{ fontFamily: 'Inter-Bold', color: dark ? '#FFF' : '#000' }}>{item.user}</Text> {item.content}
                    </Text>
                    <Text style={[styles.itemTime, { color: dark ? '#555' : '#AAA' }]}>{item.time}</Text>
                </View>
            </View>
            <ChevronRight size={16} color={dark ? '#333' : '#DDD'} />
        </TouchableOpacity>
    );
});

const SocialItem = memo(({ item, dark, blurPhotos }: any) => {
    return (
        <TouchableOpacity style={[styles.itemContainer, { borderBottomColor: dark ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.05)' }]} activeOpacity={0.7}>
            <View style={styles.itemLeft}>
                <Image source={{ uri: item.avatar }} style={styles.itemAvatar} blurRadius={blurPhotos ? 12 : 0} />
                <View style={styles.itemInfo}>
                    <Text style={[styles.itemTitle, { color: dark ? '#FFF' : '#000', fontFamily: 'Inter-Bold' }]}>{item.user}</Text>
                    <Text style={[styles.itemSubtitle, { color: dark ? '#666' : '#999' }]} numberOfLines={1}>{item.bio}</Text>
                </View>
            </View>
            <TouchableOpacity style={[
                styles.followBtn, 
                { backgroundColor: item.isFollowing ? (dark ? '#1A1A1A' : '#F5F5F5') : (dark ? '#FFF' : '#000') }
            ]}>
                <Text style={[
                    styles.followBtnText, 
                    { color: item.isFollowing ? (dark ? '#FFF' : '#000') : (dark ? '#000' : '#FFF') }
                ]}>
                    {item.isFollowing ? 'Following' : 'Follow'}
                </Text>
            </TouchableOpacity>
        </TouchableOpacity>
    );
});

const VisitItem = memo(({ item, dark, blurPhotos }: any) => {
    return (
        <TouchableOpacity style={[styles.itemContainer, { borderBottomColor: dark ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.05)' }]} activeOpacity={0.7}>
            <View style={styles.itemLeft}>
                <Image source={{ uri: item.avatar }} style={styles.itemAvatar} blurRadius={blurPhotos ? 12 : 0} />
                <View style={styles.itemInfo}>
                    <Text style={[styles.itemTitle, { color: dark ? '#E0E0E0' : '#333' }]}>
                        <Text style={{ fontFamily: 'Inter-Bold', color: dark ? '#FFF' : '#000' }}>{item.user}</Text> {item.type === 'viewer' ? 'viewed your profile' : 'profile you visited'}
                    </Text>
                    <Text style={[styles.itemTime, { color: dark ? '#555' : '#AAA' }]}>{item.time}</Text>
                </View>
            </View>
            <Eye size={16} color={dark ? '#222' : '#EEE'} />
        </TouchableOpacity>
    );
});

export default function ActivityScreen() {
    const { colors, dark } = useTheme();
    const blurPhotos = useAppSelector(state => state.system.blurPhotos);
    const [activeTab, setActiveTab] = useState<'alerts' | 'social' | 'visitors' | 'visited'>('alerts');
    const insets = useSafeAreaInsets();
    const router = useRouter();
    
    const TABS = [
        { id: 'alerts', label: 'Alerts', icon: Bell },
        { id: 'social', label: 'Social', icon: Users },
        { id: 'visitors', label: 'Visitors', icon: Eye },
        { id: 'visited', label: 'History', icon: History },
    ];

    const renderItem = useCallback(({ item }: any) => {
        if (activeTab === 'alerts') return <NotificationItem item={item} dark={dark} blurPhotos={blurPhotos} />;
        if (activeTab === 'social') return <SocialItem item={item} dark={dark} blurPhotos={blurPhotos} />;
        return <VisitItem item={item} dark={dark} blurPhotos={blurPhotos} />;
    }, [activeTab, dark, blurPhotos]);

    const getData = () => {
        switch(activeTab) {
            case 'alerts': return NOTIFICATIONS;
            case 'social': return SOCIAL;
            case 'visitors': return VISITORS;
            case 'visited': return VISITED;
            default: return [];
        }
    };

    const bgColor = dark ? '#000' : '#FFF';
    const borderColor = dark ? '#111' : '#F0F0F0';
    const tabItemBg = dark ? '#0A0A0A' : '#F9F9F9';

    return (
        <View style={[styles.container, { backgroundColor: bgColor }]}>
            <StatusBar barStyle={dark ? 'light-content' : 'dark-content'} />
            
            {/* Premium Capsule Tab Switcher */}
            <View style={[styles.header, { marginTop: 60 + insets.top }]}>
                <ScrollView 
                    horizontal 
                    showsHorizontalScrollIndicator={false}
                    contentContainerStyle={styles.tabScrollContent}
                >
                    {TABS.map((tab) => {
                        const isActive = activeTab === tab.id;
                        return (
                            <TouchableOpacity 
                                key={tab.id}
                                onPress={() => setActiveTab(tab.id as any)}
                                style={[
                                    styles.premiumTab,
                                    { 
                                        backgroundColor: isActive ? (dark ? '#FFF' : '#000') : tabItemBg,
                                        borderColor: isActive ? (dark ? '#FFF' : '#000') : borderColor,
                                    }
                                ]}
                                activeOpacity={0.8}
                            >
                                <tab.icon 
                                    size={16} 
                                    color={isActive ? (dark ? '#000' : '#FFF') : (dark ? '#444' : '#AAA')} 
                                    strokeWidth={isActive ? 2.5 : 2} 
                                />
                                <Text style={[
                                    styles.premiumTabText,
                                    { 
                                        color: isActive ? (dark ? '#000' : '#FFF') : (dark ? '#666' : '#888'),
                                    }
                                ]}>
                                    {tab.label}
                                </Text>
                            </TouchableOpacity>
                        );
                    })}
                </ScrollView>
            </View>

            <View style={{ flex: 1, paddingBottom: Platform.OS === 'ios' ? 88 : 68 }}>
                <FlashListAny
                    data={getData() as any[]}
                    renderItem={renderItem}
                    estimatedItemSize={80}
                    keyExtractor={(item: any) => item.id}
                    showsVerticalScrollIndicator={false}
                    contentContainerStyle={{ paddingTop: 8, paddingBottom: 20 }}
                    ListEmptyComponent={
                        <View style={styles.emptyContainer}>
                            <Text style={{ color: dark ? '#333' : '#CCC', fontFamily: 'Inter-Medium' }}>No activity found yet.</Text>
                        </View>
                    }
                />
            </View>
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
    },
    header: {
        width: '100%',
        paddingVertical: 12,
        zIndex: 10,
    },
    tabScrollContent: {
        paddingHorizontal: 16,
        gap: 8,
    },
    premiumTab: {
        flexDirection: 'row',
        alignItems: 'center',
        paddingHorizontal: 18,
        paddingVertical: 10,
        borderRadius: 24,
        borderWidth: 1,
        gap: 8,
    },
    premiumTabText: {
        fontSize: 13,
        fontFamily: 'Inter-Bold',
        letterSpacing: -0.2,
    },
    itemContainer: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        paddingVertical: 16,
        paddingHorizontal: 16,
        borderBottomWidth: 1,
    },
    itemLeft: {
        flexDirection: 'row',
        alignItems: 'center',
        flex: 1,
    },
    avatarContainer: {
        position: 'relative',
    },
    itemAvatar: {
        width: 50,
        height: 50,
        borderRadius: 25,
    },
    iconBadge: {
        position: 'absolute',
        bottom: -2,
        right: -2,
        borderRadius: 12,
        width: 20,
        height: 20,
        alignItems: 'center',
        justifyContent: 'center',
        borderWidth: 2,
        shadowColor: '#000',
        shadowOpacity: 0.05,
        shadowRadius: 2,
        elevation: 1,
    },
    itemInfo: {
        marginLeft: 16,
        flex: 1,
    },
    itemTitle: {
        fontSize: 14,
        lineHeight: 20,
        fontFamily: 'Inter-Regular',
    },
    itemSubtitle: {
        fontSize: 12,
        fontFamily: 'Inter-Regular',
        marginTop: 2,
    },
    itemTime: {
        fontSize: 11,
        fontFamily: 'Inter-Medium',
        marginTop: 4,
    },
    followBtn: {
        paddingHorizontal: 16,
        paddingVertical: 8,
        borderRadius: 20,
    },
    followBtnText: {
        fontSize: 12,
        fontFamily: 'Inter-Bold',
    },
    emptyContainer: {
        padding: 60,
        alignItems: 'center',
        justifyContent: 'center',
    },
});
