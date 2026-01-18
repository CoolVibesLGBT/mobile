import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';
import React, { useState, useRef } from 'react';
import { View, Text, Image, StyleSheet, TouchableOpacity, Animated } from 'react-native';

export const TAG_ICONS: { [key: string]: string } = {
  'Happy Hour': 'beer',
  'Bot': 'robot-outline',
  'Brunch': 'croissant',
  'Hydrating': 'cup-water',
  'Dinner': 'silverware-fork-knife',
};

export const TAG_COLORS: { [key: string]: { bg: string; text: string; icon: string } } = {
    'Happy Hour': { bg: '#fef9c3', text: '#854d0e', icon: '#a16207' }, // Yellow
    'Dinner':     { bg: '#fee2e2', text: '#991b1b', icon: '#b91c1c' }, // Red
    'Brunch':     { bg: '#ffedd5', text: '#9a3412', icon: '#c2410c' }, // Orange
    'Hydrating':  { bg: '#dbeafe', text: '#1e40af', icon: '#2563eb' }, // Blue
    'Bot':        { bg: '#e5e7eb', text: '#374151', icon: '#4b5563' }, // Gray
    'Default':    { bg: '#e5e7eb', text: '#374151', icon: '#4b5563' }, // Gray
};

export type CheckIn = {
  id: string;
  avatar: string;
  name: string;
  timestamp: string;
  note: string;
  image?: string;
  tags: string[];
  likes: number;
  comments: number;
};

export const CheckInItem: React.FC<{ item: CheckIn }> = ({ item }) => {
  const [isLiked, setIsLiked] = useState(false);
  const [likeCount, setLikeCount] = useState(item.likes);
  const scaleAnimation = useRef(new Animated.Value(1)).current;

  const handleLike = () => {
    const newLikedState = !isLiked;
    setIsLiked(newLikedState);
    setLikeCount(newLikedState ? likeCount + 1 : likeCount - 1);

    scaleAnimation.setValue(0.8);
    Animated.spring(scaleAnimation, {
      toValue: 1,
      bounciness: 15,
      speed: 20,
      useNativeDriver: true,
    }).start();
  };

  const animatedStyle = {
    transform: [{ scale: scaleAnimation }],
  };

  return (
    <View style={styles.itemContainer}>
      <View style={styles.header}>
        <View style={styles.userInfo}>
          <Image source={{ uri: item.avatar }} style={styles.avatar} />
          <View>
            <Text style={styles.name}>{item.name}</Text>
            <Text style={styles.timestamp}>{item.timestamp}</Text>
          </View>
        </View>
        <TouchableOpacity style={styles.moreButton}>
            <MaterialCommunityIcons name="dots-horizontal" size={28} color="#94a3b8" />
        </TouchableOpacity>
      </View>

      <Text style={styles.note}>{item.note}</Text>
      
      <View style={styles.tagsContainer}>
        {item.tags.map(tag => {
          const iconName = TAG_ICONS[tag];
          const colors = TAG_COLORS[tag] || TAG_COLORS['Default'];
          return (
            <View key={tag} style={[styles.tag, {backgroundColor: colors.bg}]}>
              {iconName && <MaterialCommunityIcons name={iconName} size={16} color={colors.icon} />}
              <Text style={[styles.tagText, {color: colors.text}]}>{tag}</Text>
            </View>
          );
        })}
      </View>
      
      {item.image && (
        <View style={styles.postImageContainer}>
          <Image source={{ uri: item.image }} style={styles.postImage} />
        </View>
      )}

      <View style={styles.footer}>
          <TouchableOpacity style={styles.actionButton} onPress={handleLike}>
            <Animated.View style={animatedStyle}>
              <MaterialCommunityIcons name={isLiked ? "heart" : "heart-outline"} size={26} color={isLiked ? "#ef4444" : "#475569"} />
            </Animated.View>
            <Text style={[styles.actionText, {color: isLiked ? "#ef4444" : "#475569"}]}>{likeCount}</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.actionButton}>
            <MaterialCommunityIcons name="comment-text-multiple-outline" size={26} color="#475569" />
            <Text style={styles.actionText}>{item.comments}</Text>
          </TouchableOpacity>
        <TouchableOpacity style={styles.actionButton}>
            <MaterialCommunityIcons name="share-variant-outline" size={26} color="#475569" />
        </TouchableOpacity>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
    itemContainer: {
        paddingHorizontal: 10,
        paddingVertical: 10,
        backgroundColor:"white",
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 2 },
        shadowOpacity: 0.25,
        shadowRadius: 3.84,
        elevation: 2,
        borderRadius: 10,
        marginBottom: 10,
    },
    header: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        paddingHorizontal: 16,
        marginBottom: 16,
    },
    userInfo: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 16,
    },
    avatar: {
        width: 50,
        height: 50,
        borderRadius: 25,
    },
    name: {
        fontSize: 17,
        fontWeight: 'bold',
        color: '#1e293b',
    },
    timestamp: {
        fontSize: 14,
        color: '#94a3b8',
        marginTop: 2,
    },
    moreButton: {
        padding: 8,
    },
    note: {
        color: '#334155',
        fontSize: 17,
        lineHeight: 28,
        paddingHorizontal: 16,
        marginBottom: 20,
    },
    postImageContainer: {
        marginTop: 8,
        backgroundColor: '#f1f5f9',
    },
    postImage: {
        width: '100%',
        height: 400,
    },
    tagsContainer: {
        flexDirection: 'row',
        flexWrap: 'wrap',
        gap: 10,
        paddingHorizontal: 16,
    },
    tag: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 8,
        borderRadius: 20,
        paddingHorizontal: 14,
        paddingVertical: 8,
    },
    tagText: {
        fontSize: 13,
        fontWeight: '600',
    },
    footer: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-around',
        paddingVertical: 10,
        paddingHorizontal: 16,
    },
    actionButton: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 10,
        padding: 8,
    },
    actionText: {
        fontSize: 16,
        fontWeight: '600',
    },
});
