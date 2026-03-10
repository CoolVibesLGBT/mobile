import React, { useState, useRef, useEffect } from 'react';
import {
    View,
    Text,
    StyleSheet,
    Modal,
    TouchableOpacity,
    TextInput,
    ActivityIndicator,
    Animated,
    Dimensions,
    KeyboardAvoidingView,
    Platform,
    ScrollView,
} from 'react-native';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useTheme } from '@react-navigation/native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { loginThunk, registerThunk } from '@/store/slice/auth';
import * as SecureStore from 'expo-secure-store';

interface AuthWizardProps {
    isOpen: boolean;
    onClose: () => void;
    mode?: 'modal' | 'standalone';
    initialAuthMode?: 'login' | 'register' | null;
}

const { width, height } = Dimensions.get('window');

const AuthWizard: React.FC<AuthWizardProps> = ({ 
    isOpen, 
    onClose, 
    mode = 'modal',
    initialAuthMode = null
}) => {
    const { colors, dark } = useTheme();
    const insets = useSafeAreaInsets();
    const dispatch = useAppDispatch();
    const { loading: authLoading, error: authError } = useAppSelector(state => state.auth);

    const [currentStep, setCurrentStep] = useState(initialAuthMode ? (initialAuthMode === 'login' ? 1 : 2) : 0);
    const [authMode, setAuthMode] = useState<'login' | 'register' | null>(initialAuthMode);
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState('');
    
    const [formData, setFormData] = useState({
        nickname: '',
        password: '',
        confirmPassword: '',
        referralCode: '',
    });

    const fadeAnim = useRef(new Animated.Value(0)).current;
    const slideAnim = useRef(new Animated.Value(20)).current;

    useEffect(() => {
        if (isOpen) {
            Animated.parallel([
                Animated.timing(fadeAnim, {
                    toValue: 1,
                    duration: 300,
                    useNativeDriver: true,
                }),
                Animated.timing(slideAnim, {
                    toValue: 0,
                    duration: 300,
                    useNativeDriver: true,
                }),
            ]).start();
            
            // Initial referral code from SecureStore
            const getRef = async () => {
                const ref = await SecureStore.getItemAsync('referralCode');
                if (ref) setFormData(prev => ({ ...prev, referralCode: ref }));
            };
            getRef();
        } else {
            fadeAnim.setValue(0);
            slideAnim.setValue(20);
        }
    }, [isOpen, currentStep]);

    const handleNext = async () => {
        setError('');
        if (currentStep === 0) {
            if (authMode === 'login') {
                setCurrentStep(1); // login-form
            } else {
                setCurrentStep(2); // register-form
            }
        } else if (currentStep === 1 && authMode === 'login') {
            setIsLoading(true);
            const resultAction = await dispatch(loginThunk({
                nickname: formData.nickname,
                password: formData.password
            }));

            if (loginThunk.fulfilled.match(resultAction)) {
                // For modal mode, we close it immediately. 
                // For standalone, we wait for the Global Guard (in _layout.tsx) to redirect us to (tabs)
                if (mode === 'modal') onClose();
            } else {
                setError('Login failed. Please check your credentials.');
            }
            setIsLoading(false);
        } else if (currentStep === 2 && authMode === 'register') {
            setIsLoading(true);
            const resultAction = await dispatch(registerThunk({
                name: formData.nickname,
                nickname: formData.nickname,
                password: formData.password,
                referralCode: formData.referralCode,
                domain: "coolvibes.lgbt",
            }));

            if (registerThunk.fulfilled.match(resultAction)) {
                // For modal mode, we close it immediately. 
                // For standalone, we wait for the Global Guard (in _layout.tsx) to redirect us to (tabs)
                if (mode === 'modal') onClose();
            } else {
                setError('Registration failed. Please try again.');
            }
            setIsLoading(false);
        }
    };

    const handleBack = () => {
        setError('');
        if (currentStep === 0) {
            onClose();
        } else {
            setCurrentStep(0);
        }
    };

    const canProceed = () => {
        if (currentStep === 0) return authMode !== null;
        if (currentStep === 1) return formData.nickname.length > 0 && formData.password.length > 0;
        if (currentStep === 2) return formData.nickname.length > 0 && formData.password.length > 0 && formData.password === formData.confirmPassword;
        return false;
    };

    const iconColor = dark ? '#FFFFFF' : '#000000';
    const backgroundColor = dark ? '#000000' : '#FFFFFF';
    const cardColor = dark ? '#1A1A1A' : '#F8F8F8';
    const borderColor = dark ? '#333333' : '#EEEEEE';
    const textColor = dark ? '#FFFFFF' : '#000000';
    const secondaryTextColor = dark ? '#AAAAAA' : '#666666';

    const renderStepContent = () => {
        if (currentStep === 0) {
            return (
                <View style={styles.authModeContainer}>
                    <View style={styles.stepHeader}>
                        <View style={[styles.iconContainer, { backgroundColor: cardColor }]}>
                            <MaterialCommunityIcons name="heart" size={32} color={iconColor} />
                        </View>
                        <Text style={[styles.title, { color: textColor }]}>Welcome to CoolVibes</Text>
                        <Text style={[styles.subtitle, { color: secondaryTextColor }]}>Join our community and share your thoughts.</Text>
                    </View>
                    
                    <View style={styles.modeButtons}>
                        <TouchableOpacity 
                            onPress={() => setAuthMode('login')}
                            style={[
                                styles.modeButton, 
                                { backgroundColor: cardColor, borderColor: authMode === 'login' ? iconColor : borderColor }
                            ]}
                        >
                            <MaterialCommunityIcons name="account" size={28} color={iconColor} />
                            <Text style={[styles.modeButtonTitle, { color: textColor }]}>Sign In</Text>
                            <Text style={[styles.modeButtonSubtitle, { color: secondaryTextColor }]}>I already have an account</Text>
                        </TouchableOpacity>

                        <TouchableOpacity 
                            onPress={() => setAuthMode('register')}
                            style={[
                                styles.modeButton, 
                                { backgroundColor: cardColor, borderColor: authMode === 'register' ? iconColor : borderColor }
                            ]}
                        >
                            <MaterialCommunityIcons name="heart-plus" size={28} color={iconColor} />
                            <Text style={[styles.modeButtonTitle, { color: textColor }]}>Sign Up</Text>
                            <Text style={[styles.modeButtonSubtitle, { color: secondaryTextColor }]}>I want to join</Text>
                        </TouchableOpacity>
                    </View>
                </View>
            );
        }

        if (currentStep === 1) {
            return (
                <View style={styles.formContainer}>
                    <View style={styles.stepHeader}>
                        <View style={[styles.iconContainer, { backgroundColor: cardColor }]}>
                            <MaterialCommunityIcons name="account" size={32} color={iconColor} />
                        </View>
                        <Text style={[styles.title, { color: textColor }]}>Sign In</Text>
                        <Text style={[styles.subtitle, { color: secondaryTextColor }]}>Enter your credentials to continue.</Text>
                    </View>

                    <View style={styles.inputs}>
                        <View style={styles.inputWrapper}>
                            <Text style={[styles.inputLabel, { color: secondaryTextColor }]}>Nickname / Email</Text>
                            <TextInput 
                                style={[styles.input, { backgroundColor: cardColor, borderColor: borderColor, color: textColor }]}
                                value={formData.nickname}
                                onChangeText={(v) => setFormData(prev => ({ ...prev, nickname: v.toLowerCase() }))}
                                placeholder="nickname"
                                placeholderTextColor={dark ? '#555' : '#AAA'}
                                autoCapitalize="none"
                            />
                        </View>
                        <View style={styles.inputWrapper}>
                            <Text style={[styles.inputLabel, { color: secondaryTextColor }]}>Password</Text>
                            <TextInput 
                                style={[styles.input, { backgroundColor: cardColor, borderColor: borderColor, color: textColor }]}
                                value={formData.password}
                                onChangeText={(v) => setFormData(prev => ({ ...prev, password: v }))}
                                placeholder="••••••••"
                                placeholderTextColor={dark ? '#555' : '#AAA'}
                                secureTextEntry
                            />
                        </View>
                    </View>
                </View>
            );
        }

        if (currentStep === 2) {
             return (
                <View style={styles.formContainer}>
                    <View style={styles.stepHeader}>
                        <View style={[styles.iconContainer, { backgroundColor: cardColor }]}>
                            <MaterialCommunityIcons name="account-plus" size={32} color={iconColor} />
                        </View>
                        <Text style={[styles.title, { color: textColor }]}>Create Account</Text>
                        <Text style={[styles.subtitle, { color: secondaryTextColor }]}>Join CoolVibes today.</Text>
                    </View>

                    <View style={styles.inputs}>
                        <View style={styles.inputWrapper}>
                            <Text style={[styles.inputLabel, { color: secondaryTextColor }]}>Nickname</Text>
                            <TextInput 
                                style={[styles.input, { backgroundColor: cardColor, borderColor: borderColor, color: textColor }]}
                                value={formData.nickname}
                                onChangeText={(v) => setFormData(prev => ({ ...prev, nickname: v.toLowerCase() }))}
                                placeholder="unique_nickname"
                                placeholderTextColor={dark ? '#555' : '#AAA'}
                                autoCapitalize="none"
                            />
                        </View>
                        <View style={styles.inputWrapper}>
                            <Text style={[styles.inputLabel, { color: secondaryTextColor }]}>Password</Text>
                            <TextInput 
                                style={[styles.input, { backgroundColor: cardColor, borderColor: borderColor, color: textColor }]}
                                value={formData.password}
                                onChangeText={(v) => setFormData(prev => ({ ...prev, password: v }))}
                                placeholder="••••••••"
                                placeholderTextColor={dark ? '#555' : '#AAA'}
                                secureTextEntry
                            />
                        </View>
                        <View style={styles.inputWrapper}>
                            <Text style={[styles.inputLabel, { color: secondaryTextColor }]}>Confirm Password</Text>
                            <TextInput 
                                style={[styles.input, { backgroundColor: cardColor, borderColor: borderColor, color: textColor }]}
                                value={formData.confirmPassword}
                                onChangeText={(v) => setFormData(prev => ({ ...prev, confirmPassword: v }))}
                                placeholder="••••••••"
                                placeholderTextColor={dark ? '#555' : '#AAA'}
                                secureTextEntry
                            />
                        </View>
                        <View style={styles.inputWrapper}>
                            <Text style={[styles.inputLabel, { color: secondaryTextColor }]}>Referral Code (Optional)</Text>
                            <TextInput 
                                style={[styles.input, { backgroundColor: cardColor, borderColor: borderColor, color: textColor }]}
                                value={formData.referralCode}
                                onChangeText={(v) => setFormData(prev => ({ ...prev, referralCode: v }))}
                                placeholder="referral code"
                                placeholderTextColor={dark ? '#555' : '#AAA'}
                                autoCapitalize="characters"
                            />
                        </View>
                    </View>
                </View>
            );
        }

        return null;
    };

    const mainContent = (
        <View style={mode === 'modal' ? styles.overlay : styles.standaloneContainer}>
            {mode === 'modal' && <TouchableOpacity activeOpacity={1} style={styles.backdrop} onPress={onClose} />}
            <KeyboardAvoidingView 
                behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
                style={styles.keyboardView}
            >
                <Animated.View style={[
                    mode === 'modal' ? styles.modalContainer : styles.standaloneContent, 
                    { 
                        backgroundColor: backgroundColor,
                        opacity: fadeAnim,
                        transform: [{ translateY: slideAnim }]
                    }
                ]}>
                    <View style={[styles.header, { paddingTop: mode === 'standalone' ? insets.top + 10 : 20 }]}>
                        <View style={styles.progressContainer}>
                            <View style={[styles.progressBar, { backgroundColor: borderColor }]}>
                                <View style={[
                                    styles.progressFill, 
                                    { 
                                        backgroundColor: textColor, 
                                        width: `${((currentStep + 1) / (authMode === 'login' ? 2 : 2.5)) * 100}%` 
                                    }
                                ]} />
                            </View>
                        </View>
                        <TouchableOpacity style={styles.closeButton} onPress={onClose}>
                            <MaterialCommunityIcons name="close" size={24} color={secondaryTextColor} />
                        </TouchableOpacity>
                    </View>

                    <ScrollView 
                        contentContainerStyle={styles.scrollContent}
                        showsVerticalScrollIndicator={false}
                    >
                        {renderStepContent()}

                        {error ? (
                            <View style={[styles.errorBox, { backgroundColor: dark ? '#331111' : '#FFEEEE' }]}>
                                <Text style={styles.errorText}>{error}</Text>
                            </View>
                        ) : null}
                    </ScrollView>

                    <View style={[styles.footer, { paddingBottom: mode === 'standalone' ? insets.bottom + 20 : 20 }]}>
                        <TouchableOpacity 
                            style={[styles.backButton, { backgroundColor: cardColor }]}
                            onPress={handleBack}
                        >
                            <MaterialCommunityIcons name="arrow-left" size={20} color={textColor} />
                            <Text style={[styles.backText, { color: textColor }]}>Back</Text>
                        </TouchableOpacity>

                        <TouchableOpacity 
                            style={[
                                styles.nextButton, 
                                { backgroundColor: canProceed() ? textColor : borderColor }
                            ]}
                            disabled={!canProceed() || isLoading}
                            onPress={handleNext}
                        >
                            {isLoading ? (
                                <ActivityIndicator size="small" color={backgroundColor} />
                            ) : (
                                <>
                                    <Text style={[styles.nextText, { color: backgroundColor }]}>
                                        {currentStep === 1 && authMode === 'login' ? 'Sign In' : (currentStep === 2 ? 'Complete' : 'Continue')}
                                    </Text>
                                    <MaterialCommunityIcons name="arrow-right" size={20} color={backgroundColor} />
                                </>
                            )}
                        </TouchableOpacity>
                    </View>
                </Animated.View>
            </KeyboardAvoidingView>
        </View>
    );

    if (mode === 'standalone') {
        return mainContent;
    }

    return (
        <Modal
            transparent
            visible={isOpen}
            animationType="fade"
            onRequestClose={onClose}
        >
            {mainContent}
        </Modal>
    );
};

const styles = StyleSheet.create({
    overlay: {
        flex: 1,
        justifyContent: 'flex-end',
        alignItems: 'center',
    },
    backdrop: {
        ...StyleSheet.absoluteFillObject,
        backgroundColor: 'rgba(0,0,0,0.8)',
    },
    keyboardView: {
        width: '100%',
        justifyContent: 'flex-end',
        alignItems: 'center',
    },
    modalContainer: {
        width: '100%',
        maxHeight: height * 0.9,
        borderTopLeftRadius: 32,
        borderTopRightRadius: 32,
        paddingBottom: Platform.OS === 'ios' ? 40 : 20,
    },
    standaloneContainer: {
        flex: 1,
        justifyContent: 'center',
        alignItems: 'center',
        width: '100%',
    },
    standaloneContent: {
        width: '100%',
        height: '100%',
    },
    header: {
        flexDirection: 'row',
        alignItems: 'center',
        padding: 20,
        paddingBottom: 10,
    },
    progressContainer: {
        flex: 1,
        marginRight: 15,
    },
    progressBar: {
        height: 6,
        borderRadius: 3,
        overflow: 'hidden',
    },
    progressFill: {
        height: '100%',
        borderRadius: 3,
    },
    closeButton: {
        width: 36,
        height: 36,
        borderRadius: 18,
        alignItems: 'center',
        justifyContent: 'center',
    },
    scrollContent: {
        paddingHorizontal: 24,
        paddingTop: 10,
        paddingBottom: 20,
    },
    stepHeader: {
        alignItems: 'center',
        marginBottom: 30,
    },
    iconContainer: {
        width: 72,
        height: 72,
        borderRadius: 24,
        alignItems: 'center',
        justifyContent: 'center',
        marginBottom: 20,
    },
    title: {
        fontSize: 24,
        fontWeight: 'bold',
        textAlign: 'center',
        marginBottom: 8,
    },
    subtitle: {
        fontSize: 16,
        textAlign: 'center',
        lineHeight: 22,
    },
    authModeContainer: {
        width: '100%',
    },
    modeButtons: {
        gap: 12,
    },
    modeButton: {
        padding: 20,
        borderRadius: 24,
        borderWidth: 2,
        alignItems: 'center',
    },
    modeButtonTitle: {
        fontSize: 18,
        fontWeight: 'bold',
        marginTop: 12,
        marginBottom: 4,
    },
    modeButtonSubtitle: {
        fontSize: 14,
        opacity: 0.8,
    },
    formContainer: {
        width: '100%',
    },
    inputs: {
        gap: 16,
    },
    inputWrapper: {
        gap: 8,
    },
    inputLabel: {
        fontSize: 14,
        fontWeight: '500',
        marginLeft: 4,
    },
    input: {
        height: 56,
        borderRadius: 16,
        borderWidth: 1,
        paddingHorizontal: 20,
        fontSize: 16,
    },
    errorBox: {
        marginTop: 20,
        padding: 16,
        borderRadius: 16,
        borderWidth: 1,
        borderColor: '#FF000033',
    },
    errorText: {
        color: '#FF4444',
        textAlign: 'center',
        fontSize: 14,
        fontWeight: '500',
    },
    footer: {
        flexDirection: 'row',
        paddingHorizontal: 24,
        paddingTop: 10,
        gap: 12,
    },
    backButton: {
        flex: 1,
        height: 56,
        borderRadius: 16,
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 8,
    },
    backText: {
        fontSize: 16,
        fontWeight: '600',
    },
    nextButton: {
        flex: 2,
        height: 56,
        borderRadius: 16,
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 8,
    },
    nextText: {
        fontSize: 16,
        fontWeight: 'bold',
    },
});

export default AuthWizard;
