import React from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, Dimensions } from 'react-native';
import { Image } from 'expo-image';
import { useTheme } from '@react-navigation/native';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import PostCard from '@/components/PostCard';

const { width } = Dimensions.get('window');

const STORIES = [
    { id: 1, name: 'Alex', avatar: 'https://i.pravatar.cc/150?u=alex', active: true },
    { id: 2, name: 'Jordan', avatar: 'https://i.pravatar.cc/150?u=jordan', active: true },
    { id: 3, name: 'Taylor', avatar: 'https://i.pravatar.cc/150?u=taylor', active: false },
    { id: 4, name: 'Chris', avatar: 'https://i.pravatar.cc/150?u=chris', active: true },
    { id: 5, name: 'Sam', avatar: 'https://i.pravatar.cc/150?u=sam', active: false },
    { id: 6, name: 'Robin', avatar: 'https://i.pravatar.cc/150?u=robin', active: true },
];

const POSTS = [
    {
        id: 1,
        user: { name: 'Jordan Blue', username: 'jordan_b', avatar: 'https://i.pravatar.cc/150?u=jordan' },
        image: 'https://picsum.photos/800/800?random=1',
        caption: 'Enjoying the vibes today. #coolvibes #community',
        likes: 1240,
        comments: 48,
        time: '2 hours ago',
    },
    {
        id: 2,
        user: { name: 'Taylor Swift', username: 'taylor_s', avatar: 'https://i.pravatar.cc/150?u=taylor' },
        image: 'https://picsum.photos/800/800?random=2',
        caption: 'New music coming soon! Stay tuned. ✨',
        likes: 8500,
        comments: 320,
        time: '5 hours ago',
    },
    {
        id: 3,
        user: { name: 'Chris Evans', username: 'cevans', avatar: 'https://i.pravatar.cc/150?u=chris' },
        image: 'https://picsum.photos/800/800?random=3',
        caption: 'Morning workout done! 💪',
        likes: 4500,
        comments: 110,
        time: '8 hours ago',
    },
];

export default function DiscoverScreen({ hideHeader = false }: { hideHeader?: boolean }) {
    const { colors, dark } = useTheme();
    const insets = useSafeAreaInsets();

    const iconColor = dark ? '#FFFFFF' : '#000000';
    const borderColor = dark ? '#1A1A1A' : '#F0F0F0';
    
    return (
        <View style={[styles.container, { backgroundColor: colors.background }]}>
            {/* Custom Header - DISABLED as we use GlobalHeader */}

            <ScrollView 
                showsVerticalScrollIndicator={false} 
                contentContainerStyle={{ 
                    paddingTop: hideHeader ? 0 : (60 + insets.top), 
                    paddingBottom: 100 
                }}
            >
                {/* Stories Section */}
                <View style={[styles.storiesWrapper, { borderBottomColor: borderColor }]}>
                    <ScrollView 
                        horizontal 
                        showsHorizontalScrollIndicator={false} 
                        contentContainerStyle={styles.storiesContainer}
                    >
                        <TouchableOpacity style={styles.storyItem}>
                            <View style={[styles.myStoryContainer, { backgroundColor: dark ? '#1A1A1A' : '#F5F5F5' }]}>
                                <MaterialCommunityIcons name="plus" size={24} color={colors.text} />
                            </View>
                            <Text style={[styles.storyName, { color: colors.text }]}>Add Story</Text>
                        </TouchableOpacity>

                        {STORIES.map(story => (
                            <TouchableOpacity key={story.id} style={styles.storyItem}>
                                <View style={[
                                    styles.storyAvatarContainer, 
                                    { borderColor: story.active ? colors.text : (dark ? '#333' : '#EEE') }
                                ]}>
                                    <Image source={{ uri: story.avatar }} style={styles.storyAvatar} contentFit="cover" />
                                </View>
                                <Text style={[styles.storyName, { color: colors.text }]} numberOfLines={1}>{story.name}</Text>
                            </TouchableOpacity>
                        ))}
                    </ScrollView>
                </View>

                {/* Posts Section */}
                <View style={styles.postsContainer}>
                    {POSTS.map(post => (
                        <PostCard key={post.id} {...post} />
                    ))}
                </View>

                {/* Bottom Padding */}
                <View style={{ height: 120 }} />
            </ScrollView>
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
    },
    header: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        paddingHorizontal: 16,
        paddingTop: 50,
        paddingBottom: 15,
        borderBottomWidth: 1,
    },
    logoText: {
        fontSize: 26,
        fontWeight: '900',
        letterSpacing: -1.2,
    },
    headerIcons: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 16,
    },
    headerIcon: {
        padding: 4,
    },
    storiesWrapper: {
        paddingVertical: 15,
        borderBottomWidth: 1,
    },
    storiesContainer: {
        paddingHorizontal: 16,
        gap: 16,
    },
    storyItem: {
        alignItems: 'center',
        width: 72,
    },
    myStoryContainer: {
        width: 66,
        height: 66,
        borderRadius: 33,
        alignItems: 'center',
        justifyContent: 'center',
        marginBottom: 8,
        borderWidth: 1,
        borderColor: 'rgba(0,0,0,0.05)',
    },
    storyAvatarContainer: {
        width: 66,
        height: 66,
        borderRadius: 33,
        borderWidth: 2,
        padding: 2,
        alignItems: 'center',
        justifyContent: 'center',
        marginBottom: 8,
    },
    storyAvatar: {
        width: 58,
        height: 58,
        borderRadius: 29,
    },
    storyName: {
        fontSize: 12,
        fontFamily: 'Inter-SemiBold',
        letterSpacing: -0.2,
    },
    postsContainer: {
        width: '100%',
    },
});