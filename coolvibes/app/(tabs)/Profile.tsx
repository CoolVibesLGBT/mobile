import React, { useEffect, useState } from 'react';
import { View, StyleSheet, StatusBar, RefreshControl, ActivityIndicator } from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import FullProfileView from '@/components/FullProfileView';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { getSafeImageURL, getSafeImageURLEx } from '@/helpers/safeUrl';
import { getAuthUserThunk } from '@/store/slice/auth';
import { toSafeBioHtml } from '@/helpers/lexicalPlainText';

export default function ProfileScreen() {
  const { dark } = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const dispatch = useAppDispatch();
  const authUser = useAppSelector(state => state.auth.user);
  const authLoading = useAppSelector(state => state.auth.loading);
  const lang = useAppSelector(state => state.system.language) || 'en';
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    dispatch(getAuthUserThunk());
  }, [dispatch]);

  const onRefresh = async () => {
    setRefreshing(true);
    await dispatch(getAuthUserThunk());
    setRefreshing(false);
  };

  if (!authUser) {
    return (
      <View style={[styles.screen, { backgroundColor: dark ? '#000' : '#fff' }]}>
        <StatusBar translucent backgroundColor="transparent" barStyle={dark ? 'light-content' : 'dark-content'} />
        <View style={[styles.loaderContainer, { paddingTop: insets.top + 60 }]}>
          <ActivityIndicator size="small" color={dark ? '#fff' : '#000'} />
        </View>
      </View>
    );
  }

  const getLocalizedBio = (bioObj: any) => {
    if (!bioObj) return '';
    if (typeof bioObj === 'string') return bioObj;
    const text = bioObj[lang] || bioObj['en'] || Object.values(bioObj)[0] || '';
    return typeof text === 'string' ? text : '';
  };

  // Map real data to format expected by FullProfileView
  const mappedUser = {
      ...authUser,
      avatar_url: getSafeImageURLEx(authUser.id, authUser.avatar, 'large'),
      banner_url: getSafeImageURL(authUser.banner, 'large') || `https://picsum.photos/seed/${authUser.id}banner/1500/500`,
      location: authUser.location?.display || authUser.location?.city || "Earth",
      followers_count: authUser.engagements?.counts?.follower_count || 0,
      following_count: authUser.engagements?.counts?.following_count || 0,
      bio: getLocalizedBio(authUser.bio || authUser.status_message),
      bioHtml: toSafeBioHtml(getLocalizedBio(authUser.bio || authUser.status_message)),
  };

  return (
    <View style={[styles.screen, { backgroundColor: dark ? '#000' : '#fff' }]}>
        <StatusBar translucent backgroundColor="transparent" barStyle={dark ? 'light-content' : 'dark-content'} />
        <View style={{ flex: 1, paddingTop: insets.top + 60 }}>
            <FullProfileView 
              user={mappedUser} 
              isMe={true} 
              onEdit={() => router.push('/ProfileEdit')}
              onWallet={() => console.log('Wallet')}
              refreshControl={
                <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={dark ? '#fff' : '#000'} />
              }
            />
        </View>
        {authLoading && (
          <View style={[styles.bottomLoader, { bottom: insets.bottom + 12, backgroundColor: dark ? 'rgba(0,0,0,0.7)' : 'rgba(255,255,255,0.85)' }]}>
            <ActivityIndicator size="small" color={dark ? '#fff' : '#000'} />
          </View>
        )}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  loaderContainer: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  bottomLoader: { position: 'absolute', left: 0, right: 0, alignSelf: 'center', marginHorizontal: 120, paddingVertical: 8, borderRadius: 16, alignItems: 'center', justifyContent: 'center' },
});
