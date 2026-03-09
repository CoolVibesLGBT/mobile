import React, { useState, useCallback, memo } from 'react';
import {
    View,
    Text,
    StyleSheet,
    TouchableOpacity,
    ScrollView,
    Switch,
    Platform,
    Alert,
} from 'react-native';
import {
    Bell,
    Eye,
    EyeOff,
    Trash2,
    MessageSquare,
    Heart,
    Moon,
    Sun,
    Languages,
    Mail,
    ChevronRight,
    UserX,
    LogOut,
} from 'lucide-react-native';
import { useTheme } from '@react-navigation/native';
import { useRouter } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { ThemedView } from '@/components/ThemedView';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { logout } from '@/store/slice/auth';
import { setTheme } from '@/store/slice/system';

// --- Sub-components (Adapted for Mobile) ---

const SettingItem = memo(({ icon: Icon, label, subtitle, onPress, value, isToggle, danger, dark, border = true }: any) => {
    return (
        <TouchableOpacity
            onPress={onPress}
            disabled={isToggle && onPress === undefined}
            activeOpacity={0.7}
            style={[
                styles.itemContainer,
                border && { borderBottomWidth: 1, borderBottomColor: dark ? '#1A1A1A' : '#F0F0F0' }
            ]}
        >
            <View style={styles.itemLeft}>
                <View style={[
                    styles.iconBox,
                    { backgroundColor: danger 
                        ? (dark ? 'rgba(239, 68, 68, 0.1)' : '#FEF2F2') 
                        : (dark ? '#1A1A1A' : '#F8F9FA') 
                    }
                ]}>
                    <Icon 
                        size={20} 
                        color={danger ? '#EF4444' : (dark ? '#FFFFFF' : '#000000')} 
                        strokeWidth={2} 
                    />
                </View>
                <View style={styles.textBox}>
                    <Text style={[
                        styles.label, 
                        { color: danger ? '#EF4444' : (dark ? '#FFFFFF' : '#000000') }
                    ]}>
                        {label}
                    </Text>
                    {subtitle && (
                        <Text style={[styles.subtitle, { color: '#666666' }]}>
                            {subtitle}
                        </Text>
                    )}
                </View>
            </View>
            
            <View style={styles.itemRight}>
                {isToggle ? (
                    <Switch
                        value={value}
                        onValueChange={onPress}
                        trackColor={{ false: '#767577', true: dark ? '#FFFFFF' : '#000000' }}
                        thumbColor={value ? (dark ? '#000000' : '#FFFFFF') : '#f4f3f4'}
                        ios_backgroundColor="#3e3e3e"
                    />
                ) : (
                    <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                        {value && <Text style={[styles.valueText, { color: '#999999', marginRight: 4 }]}>{value}</Text>}
                        <ChevronRight size={18} color="#CCCCCC" />
                    </View>
                )}
            </View>
        </TouchableOpacity>
    );
});

const Section = memo(({ title, children, dark }: any) => (
    <View style={styles.section}>
        {title && (
            <Text style={[styles.sectionTitle, { color: '#666666' }]}>
                {title.toUpperCase()}
            </Text>
        )}
        <View style={[
            styles.sectionContent, 
            { 
                backgroundColor: dark ? '#0A0A0A' : '#FFFFFF',
                borderColor: dark ? '#1A1A1A' : '#F0F0F0',
            }
        ]}>
            {children}
        </View>
    </View>
));

export default function SettingsScreen() {
    const { colors, dark } = useTheme();
    const router = useRouter();
    const insets = useSafeAreaInsets();
    const dispatch = useAppDispatch();
    
    // Mock local settings
    const [settings, setSettings] = useState({
        pushNotifications: true,
        emailNotifications: false,
        messageNotifications: true,
        blurPhotos: false,
        showOnlineStatus: true,
    });

    const toggleSetting = (key: keyof typeof settings) => {
        setSettings(prev => ({ ...prev, [key]: !prev[key] }));
    };

    const handleLogout = () => {
        Alert.alert(
            "Log Out?",
            "Are you sure you want to sign out? You will need to login again to access your profile.",
            [
                { text: "Cancel", style: "cancel" },
                { text: "Log Out", style: "destructive", onPress: () => dispatch(logout()) }
            ]
        );
    };

    const handleDeleteAccount = () => {
        Alert.alert(
            "Delete Account?",
            "This action is permanent and cannot be undone. All your data, messages, and matches will be deleted forever.",
            [
                { text: "Cancel", style: "cancel" },
                { 
                    text: "Delete My Account", 
                    style: "destructive", 
                    onPress: () => {
                        // In a real app, you'd call an API here
                        dispatch(logout());
                        Alert.alert("Account Deleted", "Your account has been successfully removed.");
                    } 
                }
            ]
        );
    };

    return (
        <ThemedView style={styles.container}>
            <ScrollView 
                contentContainerStyle={[
                    styles.scrollContent, 
                    { 
                        paddingTop: 60 + insets.top + 20, 
                        paddingBottom: insets.bottom + 20 
                    }
                ]}
                showsVerticalScrollIndicator={false}
            >
                <Section title="Appearance" dark={dark}>
                    <SettingItem
                        icon={dark ? Moon : Sun}
                        label="Dark Mode"
                        subtitle={dark ? 'Currently using Dark' : 'Currently using Light'}
                        onPress={() => dispatch(setTheme(dark ? 'light' : 'dark'))}
                        value={dark}
                        isToggle
                        dark={dark}
                    />
                    <SettingItem
                        icon={Languages}
                        label="Language"
                        subtitle="EN"
                        onPress={() => {}}
                        dark={dark}
                        border={false}
                    />
                </Section>

                <Section title="Notifications" dark={dark}>
                    <SettingItem
                        icon={Bell}
                        label="Push Notifications"
                        subtitle="Get notified in real-time"
                        onPress={() => toggleSetting('pushNotifications')}
                        value={settings.pushNotifications}
                        isToggle
                        dark={dark}
                    />
                    <SettingItem
                        icon={Mail}
                        label="Email Notifications"
                        subtitle="Weekly updates and alerts"
                        onPress={() => toggleSetting('emailNotifications')}
                        value={settings.emailNotifications}
                        isToggle
                        dark={dark}
                    />
                    <SettingItem
                        icon={MessageSquare}
                        label="Messages"
                        subtitle="New message alerts"
                        onPress={() => toggleSetting('messageNotifications')}
                        value={settings.messageNotifications}
                        isToggle
                        dark={dark}
                        border={false}
                    />
                </Section>

                <Section title="Privacy" dark={dark}>
                    <SettingItem
                        icon={settings.blurPhotos ? EyeOff : Eye}
                        label="Blur Photos in Posts"
                        subtitle={settings.blurPhotos ? 'Photos are blurred' : 'Photos are clear'}
                        onPress={() => toggleSetting('blurPhotos')}
                        value={settings.blurPhotos}
                        isToggle
                        dark={dark}
                    />
                    <SettingItem
                        icon={Heart}
                        label="Who can see my likes"
                        subtitle="Public by default"
                        value="Everyone"
                        dark={dark}
                    />
                    <SettingItem
                        icon={settings.showOnlineStatus ? Eye : EyeOff}
                        label="Online Status"
                        subtitle="Let others know you're here"
                        onPress={() => toggleSetting('showOnlineStatus')}
                        value={settings.showOnlineStatus}
                        isToggle
                        dark={dark}
                        border={false}
                    />
                </Section>

                <Section title="Account" dark={dark}>
                    <SettingItem
                        icon={LogOut}
                        label="Log Out"
                        subtitle="Sign out from this device"
                        onPress={handleLogout}
                        danger
                        dark={dark}
                    />
                    <SettingItem
                        icon={UserX}
                        label="Delete Account"
                        subtitle="Permanently delete your data"
                        onPress={handleDeleteAccount}
                        danger
                        dark={dark}
                        border={false}
                    />
                </Section>
            </ScrollView>
        </ThemedView>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
    },
    scrollContent: {
        paddingHorizontal: 16,
    },
    section: {
        marginBottom: 24,
    },
    sectionTitle: {
        fontSize: 11,
        fontWeight: '700',
        letterSpacing: 1.5,
        marginLeft: 12,
        marginBottom: 8,
    },
    sectionContent: {
        borderRadius: 24,
        overflow: 'hidden',
        borderWidth: 1,
    },
    itemContainer: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: 16,
    },
    itemLeft: {
        flexDirection: 'row',
        alignItems: 'center',
        flex: 1,
    },
    iconBox: {
        width: 40,
        height: 40,
        borderRadius: 12,
        alignItems: 'center',
        justifyContent: 'center',
    },
    textBox: {
        marginLeft: 16,
        flex: 1,
    },
    label: {
        fontSize: 15,
        fontWeight: '600',
    },
    subtitle: {
        fontSize: 12,
        marginTop: 2,
    },
    itemRight: {
        flexDirection: 'row',
        alignItems: 'center',
    },
    valueText: {
        fontSize: 14,
        fontWeight: '500',
    },
});
