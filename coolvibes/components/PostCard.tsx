import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Dimensions, Pressable } from 'react-native';
import { Image } from 'expo-image';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useTheme } from '@react-navigation/native';
import Animated, { 
    useSharedValue, 
    useAnimatedStyle, 
    withSpring, 
    withSequence,
    withTiming,
    interpolate,
} from 'react-native-reanimated';
import * as Haptics from 'expo-haptics';

interface PostCardProps {
    user: {
        name: string;
        avatar: string;
        username: string;
        verified?: boolean;
    };
    image: string;
    caption: string;
    likes: number;
    comments: number;
    time: string;
}

const { width } = Dimensions.get('window');

const PostCard: React.FC<PostCardProps> = ({ user, image, caption, likes, comments, time }) => {
    const { colors, dark } = useTheme();
    const [isLiked, setIsLiked] = useState(false);
    const likeScale = useSharedValue(1);
    const [likeCount, setLikeCount] = useState(likes);

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

            {/* Post Image with Subtle Rounded Corners */}
            <Pressable onPress={handleLike}>
                <Image 
                    source={{ uri: image }} 
                    style={[styles.postImage, { backgroundColor: dark ? '#1C1C1E' : '#F2F2F7' }]} 
                    contentFit="cover" 
                    transition={300}
                />
            </Pressable>

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
                    <TouchableOpacity style={styles.actionButton}>
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
                
                <View style={styles.captionContainer}>
                    <Text style={[styles.caption, { color: colors.text }]}>
                        <Text style={styles.captionUsername}>{user.username} </Text>
                        {caption}
                    </Text>
                </View>
                
                {comments > 0 && (
                    <TouchableOpacity style={styles.commentsButton}>
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
    captionUsername: {
        fontFamily: 'Inter-Bold',
    },
    caption: {
        fontSize: 15,
        fontFamily: 'Inter-Regular',
        lineHeight: 20,
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
