import React from 'react';
import { View, StyleSheet, StatusBar } from 'react-native';
import { useTheme } from '@react-navigation/native';
import FullProfileView from '@/components/FullProfileView';

const mockMe = {
    id: "me",
    username: "coolvibes",
    displayname: "coolvibes",
    bio: "The best app in the world. Building the future of social media, one line of code at a time.",
    avatar_url: "https://pbs.twimg.com/profile_images/1960662542801625088/ntOOL4M-_400x400.jpg",
    banner_url: "https://pbs.twimg.com/profile_banners/4614357675/1755441597/1500x500",
    location: "San Francisco, CA",
    followers_count: 12,
    following_count: 2,
    interests: [
        { id: '1', name: 'Photography', emoji: '📷' }, 
        { id: '2', name: 'Gaming', emoji: '🎮' }, 
        { id: '3', name: 'Traveling', emoji: '✈️' }
    ],
};

export default function ProfileScreen() {
  const { dark } = useTheme();

  return (
    <View style={styles.screen}>
        <StatusBar translucent backgroundColor="transparent" barStyle={dark ? 'light-content' : 'dark-content'} />
        <View style={{ flex: 1, paddingTop: 60 }}>
            <FullProfileView user={mockMe} isMe={true} />
        </View>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
});