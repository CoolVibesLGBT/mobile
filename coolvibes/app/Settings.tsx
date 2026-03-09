import React, { useState, useCallback, memo, useMemo, useRef } from 'react';
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
    Check,
} from 'lucide-react-native';
import { useTheme } from '@react-navigation/native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { BottomSheetModal as GorhomBottomSheetModal, BottomSheetView } from '@gorhom/bottom-sheet';
import { ThemedView } from '@/components/ThemedView';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { logout } from '@/store/slice/auth';
import { setTheme, toggleBlur, setLanguage } from '@/store/slice/system';
import BaseBottomSheetModal from '@/components/BaseBottomSheetModal';

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
    const insets = useSafeAreaInsets();
    const dispatch = useAppDispatch();
    const blurPhotos = useAppSelector(state => state.system.blurPhotos);
    const language = useAppSelector(state => state.system.language);
    const languageSheetRef = useRef<GorhomBottomSheetModal>(null);
    const languageOptions = useMemo(() => ([
        { code: 'en', label: 'English', description: 'Default CoolVibes experience' },
        { code: 'tr', label: 'Türkçe', description: 'Arayüzü Türkçe kullan' },
    ]), []);
    
    // Mock local settings
    const [settings, setSettings] = useState({
        pushNotifications: true,
        emailNotifications: false,
        messageNotifications: true,
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

    const openLanguageSheet = useCallback(() => {
        languageSheetRef.current?.present();
    }, []);

    const handleLanguageChange = useCallback((value: string) => {
        dispatch(setLanguage(value));
        languageSheetRef.current?.dismiss();
    }, [dispatch]);

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
                        paddingTop: 24, 
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
                        subtitle={language === 'en' ? 'English' : 'Türkçe'}
                        onPress={openLanguageSheet}
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
                        icon={blurPhotos ? EyeOff : Eye}
                        label="Blur Photos in Posts"
                        subtitle={blurPhotos ? 'Photos are blurred' : 'Photos are clear'}
                        onPress={() => dispatch(toggleBlur())}
                        value={blurPhotos}
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

            <BaseBottomSheetModal ref={languageSheetRef}>
                <BottomSheetView style={[styles.languageSheetContent, { paddingBottom: insets.bottom + 16, backgroundColor: dark ? '#050505' : '#FFFFFF' }]}>
                    <Text style={[styles.sheetTitle, { color: colors.text }]}>Choose Language</Text>
                    {languageOptions.map(option => {
                        const isActive = language === option.code;
                        return (
                            <TouchableOpacity
                                key={option.code}
                                style={[
                                    styles.languageOption,
                                    { borderColor: dark ? '#1F1F1F' : '#F0F0F0', backgroundColor: dark ? '#111111' : '#FDFDFD' },
                                    isActive && { borderColor: dark ? '#FFFFFF' : '#111111' }
                                ]}
                                activeOpacity={0.8}
                                onPress={() => handleLanguageChange(option.code)}
                            >
                                <View style={styles.languageOptionText}>
                                    <Text style={[styles.languageOptionLabel, { color: colors.text }]}>{option.label}</Text>
                                    <Text style={[styles.languageOptionDescription, { color: dark ? '#9CA3AF' : '#6B7280' }]}>
                                        {option.description}
                                    </Text>
                                </View>
                                <View style={[
                                    styles.languageIndicator,
                                    { borderColor: dark ? '#333333' : '#D1D5DB', backgroundColor: dark ? '#0A0A0A' : '#FFFFFF' },
                                    isActive && { backgroundColor: dark ? '#ffffff12' : '#111111' }
                                ]}>
                                    {isActive && <Check size={16} color={dark ? '#FFFFFF' : '#FFFFFF'} strokeWidth={3} />}
                                </View>
                            </TouchableOpacity>
                        );
                    })}
                </BottomSheetView>
            </BaseBottomSheetModal>
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
    languageSheetContent: {
        paddingHorizontal: 20,
        paddingTop: 12,
        gap: 12,
    },
    sheetTitle: {
        fontSize: 16,
        fontWeight: '700',
        marginBottom: 4,
    },
    languageOption: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        paddingHorizontal: 16,
        paddingVertical: 14,
        borderRadius: 16,
        borderWidth: 1,
    },
    languageOptionText: {
        flex: 1,
        marginRight: 12,
    },
    languageOptionLabel: {
        fontSize: 16,
        fontWeight: '600',
    },
    languageOptionDescription: {
        fontSize: 12,
        marginTop: 4,
    },
    languageIndicator: {
        width: 36,
        height: 36,
        borderRadius: 18,
        alignItems: 'center',
        justifyContent: 'center',
        borderWidth: 1,
    },
});
