import React, { useEffect, useState } from 'react';
import { View, StyleSheet, StatusBar, RefreshControl } from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import FullProfileView from '@/components/FullProfileView';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { getSafeImageURL, getSafeImageURLEx } from '@/helpers/safeUrl';
import { getAuthUserThunk } from '@/store/slice/auth';

export default function ProfileScreen() {
  const { dark } = useTheme();
  const insets = useSafeAreaInsets();
  const dispatch = useAppDispatch();
  const authUser = useAppSelector(state => state.auth.user);
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    dispatch(getAuthUserThunk());
  }, []);

  const onRefresh = async () => {
    setRefreshing(true);
    await dispatch(getAuthUserThunk());
    setRefreshing(false);
  };

  if (!authUser) {
    return null; // Or a loading state
  }

  const lang = useAppSelector(state => state.system.language) || 'en';

  const getBio = (bioObj: any) => {
    if (!bioObj) return "";
    if (typeof bioObj === 'string') return bioObj;
    const text = bioObj[lang] || bioObj['en'] || Object.values(bioObj)[0] || "";
    // Basic HTML strip since we use standard Text component
    return typeof text === 'string' ? text.replace(/<[^>]*>?/gm, '') : "";
  };

  // Map real data to format expected by FullProfileView
  const mappedUser = {
      ...authUser,
      avatar_url: getSafeImageURLEx(authUser.id, authUser.avatar, 'large'),
      banner_url: getSafeImageURL(authUser.banner, 'large') || `https://picsum.photos/seed/${authUser.id}banner/1500/500`,
      location: authUser.location?.display || authUser.location?.city || "Earth",
      followers_count: authUser.engagements?.counts?.follower_count || 0,
      following_count: authUser.engagements?.counts?.following_count || 0,
      bio: getBio(authUser.bio || authUser.status_message),
  };

  return (
    <View style={[styles.screen, { backgroundColor: dark ? '#000' : '#fff' }]}>
        <StatusBar translucent backgroundColor="transparent" barStyle={dark ? 'light-content' : 'dark-content'} />
        <View style={{ flex: 1, paddingTop: insets.top + 60 }}>
            <FullProfileView 
              user={mappedUser} 
              isMe={true} 
              onEdit={() => console.log('Edit profile')}
              onWallet={() => console.log('Wallet')}
              refreshControl={
                <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={dark ? '#fff' : '#000'} />
              }
            />
        </View>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
});