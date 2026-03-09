import React from 'react';
import { View, StyleSheet } from 'react-native';
import { useRouter } from 'expo-router';
import AuthWizard from '@/components/AuthWizard';
import { useTheme } from '@react-navigation/native';

export default function RegisterScreen() {
    const router = useRouter();
    const { colors } = useTheme();

    return (
        <View style={[styles.container, { backgroundColor: colors.background }]}>
            <AuthWizard 
                isOpen={true} 
                onClose={() => router.back()} 
                mode="standalone"
                initialAuthMode="register"
            />
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
    },
});
