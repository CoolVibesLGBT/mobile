import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Dimensions, Pressable, ScrollView } from 'react-native';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useTheme } from '@react-navigation/native';
import { useRouter } from 'expo-router';
import Animated, { 
    useSharedValue, 
    useAnimatedStyle, 
    withSpring, 
    withSequence,
    withTiming,
    interpolate,
} from 'react-native-reanimated';
import * as Haptics from 'expo-haptics';
import { useAppSelector } from '@/store/hooks';

interface PostCardProps {
    postId?: string;
    user: {
        name: string;
        avatar: string;
        username: string;
        verified?: boolean;
    };
    image?: string;
    caption: string;
    likes: number;
    comments: number;
    time: string;
    tags?: Array<{
        key: string;
        label: string;
        icon?: string;
        gradient?: { colors: [string, string]; textColor: string };
    }>;
}

const { width } = Dimensions.get('window');

const PostCard: React.FC<PostCardProps> = ({ postId, user, image, caption, likes, comments, time, tags }) => {
    const { colors, dark } = useTheme();
    const router = useRouter();
    const blurPhotos = useAppSelector(state => state.system.blurPhotos);
    const [isLiked, setIsLiked] = useState(false);
    const likeScale = useSharedValue(1);
    const [likeCount, setLikeCount] = useState(likes);

    const openPostDetail = () => {
        if (!postId) return;
        router.push({ pathname: '/PostDetail', params: { postId } });
    };

    const handleLike = () => {
        const nextLiked = !isLiked;
        setIsLiked(nextLiked);
        setLikeCount(prev => nextLiked ? prev + 1 : prev - 1);
        
        likeScale.value = withSequence(
            withSpring(1.4, { damping: 4, stiffness: 200 }),
            withSpring(1)
        );
        
        if (nextLiked) {
            Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
        } else {
            Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
        }
    };

    const animatedLikeStyle = useAnimatedStyle(() => ({
        transform: [{ scale: likeScale.value }],
    }));

    const iconColor = dark ? '#FFFFFF' : '#000000';
    const borderColor = dark ? '#1C1C1E' : '#F2F2F7';
    const tagBg = dark ? '#1C1C1E' : '#F1F5F9';
    const tagTextColor = dark ? '#D1D5DB' : '#475569';

    return (
        <View style={[styles.container, { backgroundColor: colors.background }]}>
            {/* Divider */}
            <View style={[styles.topDivider, { backgroundColor: borderColor }]} />
            
            {/* Header */}
            <View style={styles.header}>
                <Image source={{ uri: user.avatar }} style={styles.avatar} contentFit="cover" />
                <View style={styles.userInfo}>
                    <View style={styles.nameRow}>
                        <Text style={[styles.name, { color: colors.text }]}>{user.name}</Text>
                        <MaterialCommunityIcons name="check-decagram" size={14} color={colors.text} style={styles.verifiedIcon} />
                    </View>
                    <Text style={[styles.username, { color: dark ? '#8E8E93' : '#666' }]}>@{user.username}</Text>
                </View>
                <TouchableOpacity style={styles.moreButton}>
                    <MaterialCommunityIcons name="dots-horizontal" size={22} color={iconColor} />
                </TouchableOpacity>
            </View>

            {/* Message + tags (under profile, above actions) */}
            <View style={styles.messageBlock}>
                <View style={styles.captionContainer}>
                    <Text style={[styles.caption, { color: colors.text }]}>
                        {caption}
                    </Text>
                </View>

                {Array.isArray(tags) && tags.length > 0 && (
                    <ScrollView
                        horizontal
                        showsHorizontalScrollIndicator={false}
                        contentContainerStyle={styles.tagsRow}
                    >
                        {tags.map(tag => {
                            const gradient = tag.gradient;
                            const textColor = gradient?.textColor || tagTextColor;
                            const badgeContent = tag.icon ? (
                                <MaterialCommunityIcons name={tag.icon as any} size={20} color={textColor} />
                            ) : (
                                <Text style={[styles.tagBadgeText, { color: textColor }]}>
                                    {tag.label.slice(0, 2).toUpperCase()}
                                </Text>
                            );

                            return (
                                <View key={tag.key} style={styles.tagBadgeWrap}>
                                    {gradient?.colors ? (
                                        <LinearGradient
                                            colors={gradient.colors}
                                            start={{ x: 0, y: 0 }}
                                            end={{ x: 1, y: 1 }}
                                            style={styles.tagBadge}
                                        >
                                            <View style={styles.tagBadgeRing} />
                                            <View style={styles.tagBadgeInner}>
                                                {badgeContent}
                                            </View>
                                            <View style={styles.tagBadgeGloss} />
                                        </LinearGradient>
                                    ) : (
                                        <View style={[styles.tagBadge, { backgroundColor: tagBg }]}>
                                            <View style={styles.tagBadgeRing} />
                                            <View style={styles.tagBadgeInner}>
                                                {badgeContent}
                                            </View>
                                            <View style={styles.tagBadgeGloss} />
                                        </View>
                                    )}
                                    <Text
                                        style={[styles.tagBadgeLabel, { color: tagTextColor }]}
                                        numberOfLines={1}
                                    >
                                        {tag.label}
                                    </Text>
                                </View>
                            );
                        })}
                    </ScrollView>
                )}
            </View>

            {/* Post Image with Subtle Rounded Corners */}
            {image ? (
                <Pressable onPress={handleLike}>
                    <Image 
                        source={{ uri: image }} 
                        style={[styles.postImage, { backgroundColor: dark ? '#1C1C1E' : '#F2F2F7' }]} 
                        contentFit="cover" 
                        transition={300}
                        blurRadius={blurPhotos ? 25 : 0}
                    />
                </Pressable>
            ) : null}

            {/* Actions Bar */}
            <View style={styles.actions}>
                <View style={styles.leftActions}>
                    <TouchableOpacity onPress={handleLike} style={styles.actionButton}>
                        <Animated.View style={animatedLikeStyle}>
                            <MaterialCommunityIcons 
                                name={isLiked ? "heart" : "heart-outline"} 
                                size={28} 
                                color={iconColor} 
                            />
                        </Animated.View>
                    </TouchableOpacity>
                    <TouchableOpacity style={styles.actionButton} onPress={openPostDetail}>
                        <MaterialCommunityIcons name="chat-outline" size={26} color={iconColor} />
                    </TouchableOpacity>
                    <TouchableOpacity style={styles.actionButton}>
                        <MaterialCommunityIcons name="share-variant-outline" size={26} color={iconColor} />
                    </TouchableOpacity>
                </View>
                <TouchableOpacity style={styles.actionButton}>
                    <MaterialCommunityIcons name="bookmark-outline" size={26} color={iconColor} />
                </TouchableOpacity>
            </View>

            {/* Content Area */}
            <View style={styles.content}>
                <Text style={[styles.likesText, { color: colors.text }]}>
                    {likeCount.toLocaleString()} <Text style={styles.subText}>vibes</Text>
                </Text>
                
                {comments > 0 && (
                    <TouchableOpacity style={styles.commentsButton} onPress={openPostDetail}>
                        <Text style={[styles.commentsLink, { color: dark ? '#8E8E93' : '#666' }]}>
                            View all {comments} comments
                        </Text>
                    </TouchableOpacity>
                )}
                
                <Text style={[styles.timeText, { color: dark ? '#48484A' : '#999' }]}>{time}</Text>
            </View>
        </View>
    );
};

const styles = StyleSheet.create({
    container: {
        width: '100%',
        marginBottom: 8,
    },
    topDivider: {
        height: 1,
        width: '100%',
        opacity: 0.5,
    },
    header: {
        flexDirection: 'row',
        alignItems: 'center',
        paddingHorizontal: 16,
        paddingVertical: 14,
    },
    avatar: {
        width: 40,
        height: 40,
        borderRadius: 20,
        marginRight: 12,
    },
    userInfo: {
        flex: 1,
    },
    nameRow: {
        flexDirection: 'row',
        alignItems: 'center',
    },
    name: {
        fontSize: 15,
        fontFamily: 'Inter-Bold',
        letterSpacing: -0.3,
    },
    verifiedIcon: {
        marginLeft: 4,
    },
    username: {
        fontSize: 13,
        fontFamily: 'Inter-SemiBold',
        marginTop: 1,
    },
    moreButton: {
        padding: 4,
    },
    messageBlock: {
        paddingHorizontal: 16,
        paddingBottom: 12,
    },
    postImage: {
        width: width,
        height: width,
    },
    actions: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        paddingHorizontal: 12,
        paddingVertical: 12,
    },
    leftActions: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 16,
    },
    actionButton: {
        padding: 4,
    },
    content: {
        paddingHorizontal: 16,
        paddingBottom: 16,
    },
    likesText: {
        fontSize: 15,
        fontFamily: 'Inter-Bold',
        marginBottom: 6,
    },
    subText: {
        fontFamily: 'Inter-SemiBold',
        opacity: 0.6,
    },
    captionContainer: {
        flexDirection: 'row',
        marginBottom: 8,
    },
    caption: {
        fontSize: 15,
        fontFamily: 'Inter-Regular',
        lineHeight: 20,
    },
    tagsRow: {
        flexDirection: 'row',
        alignItems: 'flex-start',
        paddingVertical: 2,
        paddingRight: 8,
        marginBottom: 10,
    },
    tagBadgeWrap: {
        alignItems: 'center',
        marginRight: 14,
        maxWidth: 72,
    },
    tagBadge: {
        width: 50,
        height: 50,
        borderRadius: 25,
        alignItems: 'center',
        justifyContent: 'center',
        borderWidth: 1,
        borderColor: 'rgba(255,255,255,0.35)',
        overflow: 'hidden',
        shadowColor: '#000',
        shadowOpacity: 0.18,
        shadowRadius: 12,
        shadowOffset: { width: 0, height: 6 },
        elevation: 5,
    },
    tagBadgeInner: {
        alignItems: 'center',
        justifyContent: 'center',
    },
    tagBadgeRing: {
        position: 'absolute',
        inset: 1,
        borderRadius: 999,
        borderWidth: 1,
        borderColor: 'rgba(255,255,255,0.2)',
    },
    tagBadgeGloss: {
        position: 'absolute',
        top: -10,
        left: -10,
        right: -10,
        height: 22,
        backgroundColor: 'rgba(255,255,255,0.25)',
        transform: [{ rotate: '-8deg' }],
    },
    tagBadgeText: {
        fontSize: 12,
        fontFamily: 'Inter-Bold',
        letterSpacing: 0.6,
    },
    tagBadgeLabel: {
        marginTop: 5,
        fontSize: 10,
        fontFamily: 'Inter-Medium',
        letterSpacing: 0.2,
        textAlign: 'center',
    },
    commentsButton: {
        marginTop: 2,
        marginBottom: 6,
    },
    commentsLink: {
        fontSize: 14,
        fontFamily: 'Inter-SemiBold',
    },
    timeText: {
        fontSize: 11,
        fontFamily: 'Inter-Bold',
        textTransform: 'uppercase',
        letterSpacing: 0.5,
    },
});

export default PostCard;
