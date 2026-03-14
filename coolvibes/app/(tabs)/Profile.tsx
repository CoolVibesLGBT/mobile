import React, { useEffect, useState } from 'react';
import { View, StyleSheet, StatusBar, RefreshControl, ActivityIndicator } from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import FullProfileView from '@/components/FullProfileView';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { getSafeImageURL, getSafeImageURLEx } from '@/helpers/safeUrl';
import { getAuthUserThunk } from '@/store/slice/auth';
import { normalizeProfileUser } from '@/helpers/profile';

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

  const normalizedUser = normalizeProfileUser(authUser, undefined, { language: lang });
  const mappedUser = {
      ...authUser,
      ...normalizedUser,
      avatar_url: getSafeImageURLEx(authUser.id, authUser.avatar, 'large') || normalizedUser?.avatar_url,
      banner_url: getSafeImageURL(authUser.banner, 'large') || normalizedUser?.banner_url || `https://picsum.photos/seed/${authUser.id}banner/1500/500`,
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
